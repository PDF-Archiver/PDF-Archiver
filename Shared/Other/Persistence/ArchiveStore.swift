//
//  ArchiveStore.swift
//  
//
//  Created by Julian Kahnert on 14.03.24.
//

import AsyncExtensions
import Foundation
import OSLog
import PDFKit.PDFDocument
import SwiftData

extension Notification.Name {
    static let documentUpdate = Notification.Name("documentUpdate")
}

actor ArchiveStore: ModelActor, Log {
    static let shared = ArchiveStore(modelContainer: container)

    #if DEBUG
    private static let availableProvider: [any FolderProvider.Type] = {
        if UserDefaults.isInDemoMode {
            return [DemoFolderProvider.self]
        } else {
            return [ICloudFolderProvider.self, LocalFolderProvider.self]
        }
    }()
    #else
    private static let availableProvider: [any FolderProvider.Type] = [ICloudFolderProvider.self, LocalFolderProvider.self]
    #endif

    // https://useyourloaf.com/blog/swiftdata-background-tasks/
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor

    var isLoadingStream = AsyncCurrentValueSubject(true)

    private var archiveFolder: URL!
    private var untaggedFolders: [URL] = []
    private var providers: [any FolderProvider] = []
    private var folderObservationTasks: [Task<Void, Never>] = []
    // Since we run a full sync at startup, we have to remove all old documents initially.
    private var removeOldDocumentsInNextSync = true

    private init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // "Apple warns you not to use the model executor to access the model context. Instead you should use the modelContext property of the actor."
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        Logger.archiveStore.trace("[SearchArchive] init called")
    }

    func update(archiveFolder: URL, untaggedFolders: [URL]) async {
        // remove all current file providers to prevent watching changes while moving folders
        providers = []
        folderObservationTasks.forEach { $0.cancel() }
        folderObservationTasks = []

        self.archiveFolder = archiveFolder
        self.untaggedFolders = untaggedFolders
        let observedFolders = [[archiveFolder], untaggedFolders]
            .flatMap { $0 }
            .getUniqueParents()
        var foundProviders: [(any FolderProvider)?] = []
        for observedFolder in observedFolders {
            let provider = await initProvider(for: observedFolder)
            foundProviders.append(provider)
        }
        providers = foundProviders.compactMap { $0 }
        for provider in providers {
            let task = Task {
                let folderChangeStream = await provider.folderChangeStream
                for await changes in folderChangeStream {
                    Self.log.debug("Found changes \(changes)")
                    self.folderDidChange(changes)
                }
            }
            folderObservationTasks.append(task)
        }
    }

    @FolderProviderActor
    private func initProvider(for folder: URL) -> FolderProvider? {
        guard let provider = Self.availableProvider.first(where: { $0.canHandle(folder) }) else {
            Logger.archiveStore.errorAndAssert("Could not find a FolderProvider - path: \(folder.path)")
            NotificationCenter.default.createAndPost(title: "Folder Provider Error", message: "Could not find a folder provider for path:\n\(folder.absoluteString)", primaryButtonTitle: "OK")
            return nil
        }
        Logger.archiveStore.debug("Initialize new provider for: \(folder.path)")
        do {
            return try provider.init(baseUrl: folder)
        } catch {
            Logger.archiveStore.error("Failed to create FolderProvider - error: \(error)")
            NotificationCenter.default.postAlert(error)
            return nil
        }
    }

    private func getProvider(for url: URL) async throws -> any FolderProvider {

        // Use `contains` instead of `prefix` to avoid problems with local files.
        // This fixes a problem, where we get different file urls back:
        // /private/var/mobile/Containers/Data/Application/8F70A72B-026D-4F6B-98E8-2C6ACE940133/Documents/untagged/document1.pdf
        //         /var/mobile/Containers/Data/Application/8F70A72B-026D-4F6B-98E8-2C6ACE940133/Documents/
        for provider in providers {
            let baseUrlPath = await provider.baseUrl.path()
            guard url.path().contains(baseUrlPath) else { continue }
            return provider
        }

        Logger.archiveStore.error("No provider found for \(url.path())")
        let baseUrls = await self.providers.asyncMap { await $0.baseUrl }
        Logger.archiveStore.debug("Providers \(baseUrls.map({ $0.path() }).joined(separator: ", "))")
        throw ArchiveStore.Error.providerNotFound
    }

    @discardableResult
    func archiveFile(from url: URL, to filename: String) async throws -> URL {
        let filename = filename.lowercased()

        let foldername = String(filename.prefix(4))

        guard let archiveFolder = self.archiveFolder else {
            throw ArchiveStore.Error.providerNotFound
        }
        let documentProvider = try await getProvider(for: url)
        let archiveProvider = try await getProvider(for: archiveFolder)

        // check, if this path already exists ... create it
        let newFilepath = archiveFolder
            .appendingPathComponent(foldername)
            .appendingPathComponent(filename)

        if await archiveProvider.baseUrl == documentProvider.baseUrl {
            try await archiveProvider.rename(from: url, to: newFilepath)
        } else {
            let documentData = try await documentProvider.fetch(url: url)
            try await archiveProvider.save(data: documentData, at: newFilepath)
            try await documentProvider.delete(url: url)
        }

        // save file tags
        if let tags = Document.parseFilename(filename).tagNames,
           !tags.isEmpty {
            newFilepath.setFileTags(tags.sorted())
        }

        return newFilepath
    }

    func startDownload(of url: URL) async {
        do {
            let provider = try await getProvider(for: url)
            try await provider.startDownload(of: url)
        } catch {
            Logger.archiveStore.errorAndAssert("Failed to start download", metadata: ["error": "\(error)"])
        }
    }

    func reloadArchiveDocuments() throws {
        Task {
            folderObservationTasks.forEach { $0.cancel() }
            folderObservationTasks.removeAll()

            let archiveUrl = try await PathManager.shared.getArchiveUrl()
            let untaggedUrl = try await PathManager.shared.getUntaggedUrl()

            #if os(macOS)
            let untaggedFolders = [untaggedUrl, UserDefaults.observedFolderURL].compactMap { $0 }
            #else
            let untaggedFolders = [untaggedUrl]
            #endif

            removeOldDocumentsInNextSync = true
            await update(archiveFolder: archiveUrl, untaggedFolders: untaggedFolders)
        }
    }

    /// Process the changes of one folder
    ///
    /// Attention: There will be a fatalError, when this function is async:
    /// ```
    /// Thread 1: Fatal error: This model instance was invalidated because its backing data could no longer be found the store. PersistentIdentifier(id: SwiftData.PersistentIdentifier.ID(backing: SwiftData.PersistentIdentifier.PersistentIdentifierBacking.managedObjectID
    /// ```
    private func folderDidChange(_ changes: [FileChange]) {
        // improve performance by caching for this "folderDidChange" run
        var tagCache: [String: PersistentIdentifier] = [:]

        // if this is the initial sync, delete all documents before this date
        let folderDidchangeStart = Date()

        do {

            // create/update documents
            for change in changes {
                try processFileChange(with: change, tagCache: &tagCache, created: folderDidchangeStart)
            }

            // we have to save the documents here, because the upsert will be done on save
            // otherwise the deletion predicate will match all documents
            try modelContext.save()

            // delete old documents in db
            if removeOldDocumentsInNextSync {
                removeOldDocumentsInNextSync = false
                let predicate = #Predicate<Document> { $0._created < folderDidchangeStart }

                // do not batch delete the documents, since sometimes a "Batch delete failed due to mandatory OTO nullify inverse on ..." occurs
                // try modelContext.delete(model: Document.self, where: predicate)
                let documents = try modelContext.fetch(.init(predicate: predicate))
                for document in documents {
                    modelContext.delete(document)
                }

                try modelContext.save()
            }

            // we have deleted the SwiftData deleteRule and use nullify since it seems more robust
            // so we need to clean up the stale tags manually
            let staleTagsPredicate = #Predicate<Tag> { $0.documents.isEmpty }
            try modelContext.delete(model: Tag.self, where: staleTagsPredicate)
            if modelContext.hasChanges {
                Logger.archiveStore.debug("Found changes after tag deletion, saving")
                try modelContext.save()
            }

            let changedUrls = changes.map(\.url)
            NotificationCenter.default.post(name: .documentUpdate, object: changedUrls)
        } catch {
            Logger.archiveStore.errorAndAssert("Error while saving data - error: \(error)")
        }

        isLoadingStream.send(false)
    }

    private func processFileChange(with fileChange: FileChange, tagCache: inout [String: PersistentIdentifier], created: Date) throws {
        switch fileChange {
        case .added(let details):
            let document = upsert(document: nil,
                                  details: details,
                                  tagCache: &tagCache,
                                  created: created)
            guard let document else {
                Logger.archiveStore.errorAndAssert("Failed to get uniqueId for delete")
                return
            }
            modelContext.insert(document)

        case .removed(let url):
            guard let id = url.uniqueId() else {
                Logger.archiveStore.errorAndAssert("Failed to get uniqueId for delete")
                return
            }

            let predicate = #Predicate<Document> {
                $0.id == id
            }
            let descriptor = FetchDescriptor<Document>(
                predicate: predicate, sortBy: [SortDescriptor(\Document.date, order: .reverse)]
            )
            let documents = try modelContext.fetch(descriptor)
            for document in documents {
                modelContext.delete(document)
            }

        case .updated(let details):
            guard let id = details.url.uniqueId() else {
                Logger.archiveStore.errorAndAssert("Failed to get uniqueId for update", metadata: ["url": details.url.path()])
                return
            }
            let predicate = #Predicate<Document> {
                $0.id == id
            }
            let descriptor = FetchDescriptor<Document>(
                predicate: predicate, sortBy: [SortDescriptor(\Document.date, order: .reverse)]
            )
            let documents = try modelContext.fetch(descriptor)
            let foundDocument = documents.first

            let document = upsert(document: foundDocument,
                                  details: details,
                                  tagCache: &tagCache,
                                  created: created)

            // insert a document if a new one was created
            if foundDocument == nil,
               let document {
                modelContext.insert(document)
            }

            assert(document != nil, "Failed to update document")
            Logger.archiveStore.debug("Updated document", metadata: ["specification": document?.specification ?? "", "downloadStatus": "\(document?.downloadStatus ?? 0)"])

            for document in documents.dropFirst() {
                assertionFailure("There should not be more than one document in the database")
                modelContext.delete(document)
            }
        }
    }

    private func isTagged(_ url: URL) -> Bool {

        // Could document be found in the untagged folder?
        guard !untaggedFolders.contains(where: { url.path.contains($0.path) }) else { return false }

        // Do "--" and "__" exist in filename?
        guard url.lastPathComponent.contains("--"),
            url.lastPathComponent.contains("__"),
            !url.lastPathComponent.lowercased().contains(Constants.documentDatePlaceholder.lowercased()),
            !url.lastPathComponent.lowercased().contains(Constants.documentDescriptionPlaceholder.lowercased()),
            !url.lastPathComponent.lowercased().contains(Constants.documentTagPlaceholder.lowercased()) else { return false }

        return true
    }

    private func upsert(document: Document?, details: FileChange.Details, tagCache: inout [String: PersistentIdentifier], created: Date) -> Document? {
        guard let id = details.url.uniqueId() else {
            Logger.archiveStore.errorAndAssert("Failed to get uniqueId")
            return nil
        }
        guard let filename = details.url.filename() else {
            Logger.archiveStore.errorAndAssert("Failed to get filename")
            return nil
        }

        let downloadStatus: Double
        switch details.downloadStatus {
        case .downloading(percent: let percent):
            downloadStatus = percent / 100
        case .remote:
            downloadStatus = 0
        case .local:
            downloadStatus = 1
        }

        let data = Document.parseFilename(filename)
        let isTagged = isTagged(details.url)

        var tags: [Tag] = []
        for tagName in data.tagNames ?? [] {
            let tag: Tag
            if let foundTagId = tagCache[tagName],
               // get Tag via the persistent identifier
               let foundTag = self[foundTagId, as: Tag.self] {
                tag = foundTag
            } else {
                tag = Tag.getOrCreate(name: tagName, in: modelContext)
                tagCache[tagName] = tag.persistentModelID
            }
            tags.append(tag)
        }

        let date = data.date ?? details.url.fileCreationDate() ?? Date()
        let specification = isTagged ? (data.specification ?? "n/a").replacingOccurrences(of: "-", with: " ") : (data.specification ?? "n/a")

        if let document {
            assert(id == document.id, "Document IDs do not match")

            document._sizeInBytes = details.sizeInBytes
            document.downloadStatus = downloadStatus
            document.url = details.url
            document.isTagged = isTagged
            document.filename = isTagged ? filename.replacingOccurrences(of: "-", with: " ") : filename
            document._sizeInBytes = details.sizeInBytes
            document.date = date
            document.specification = specification
            document.tagItems = tags
            document.downloadStatus = downloadStatus

            return document
        } else {
            return Document(id: id,
                            url: details.url,
                            isTagged: isTagged,
                            filename: isTagged ? filename.replacingOccurrences(of: "-", with: " ") : filename,
                            sizeInBytes: details.sizeInBytes,
                            date: date,
                            specification: specification,
                            tags: tags,
                            downloadStatus: downloadStatus,
                            created: created)
        }
    }
}
