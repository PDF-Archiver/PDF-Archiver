//
//  File.swift
//  
//
//  Created by Julian Kahnert on 14.03.24.
//

import Foundation
import SwiftData
import PDFKit.PDFDocument
import OSLog

actor NewArchiveStore: ModelActor {

    static let shared = NewArchiveStore(modelContainer: container)

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

    private var archiveFolder: URL!
    private var untaggedFolders: [URL] = []
    private var providers: [any FolderProvider] = []
    private let fileManager = FileManager.default

    private init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // "Apple warns you not to use the model executor to access the model context. Instead you should use the modelContext property of the actor."
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        Logger.archiveStore.trace("[SearchArchive] init called")
    }

    func update(archiveFolder: URL, untaggedFolders: [URL]) {
        assert(!Thread.isMainThread, "This should not be called from the main thread.")

        // remove all current file providers to prevent watching changes while moving folders
        providers = []

        self.archiveFolder = archiveFolder
        self.untaggedFolders = untaggedFolders
        let observedFolders = [[archiveFolder], untaggedFolders]
            .flatMap { $0 }
            .getUniqueParents()

        providers = observedFolders.compactMap { folder in
            guard let provider = Self.availableProvider.first(where: { $0.canHandle(folder) }) else {
                Logger.archiveStore.errorAndAssert("Could not find a FolderProvider - path: \(folder.path)")
                NotificationCenter.default.createAndPost(title: "Folder Provider Error", message: "Could not find a folder provider for path:\n\(folder.absoluteString)", primaryButtonTitle: "OK")
                return nil
            }
            Logger.archiveStore.debug("Initialize new provider for: \(folder.path)")
            do {
                return try provider.init(baseUrl: folder, folderDidChange(_:_:))
            } catch {
                Logger.archiveStore.error("Failed to create FolderProvider - error: \(error)")
                NotificationCenter.default.postAlert(error)
                return nil
            }
        }
    }

    func getProvider(for url: URL) throws -> any FolderProvider {

        // Use `contains` instead of `prefix` to avoid problems with local files.
        // This fixes a problem, where we get different file urls back:
        // /private/var/mobile/Containers/Data/Application/8F70A72B-026D-4F6B-98E8-2C6ACE940133/Documents/untagged/document1.pdf
        //         /var/mobile/Containers/Data/Application/8F70A72B-026D-4F6B-98E8-2C6ACE940133/Documents/

        guard let provider = providers.first(where: { url.path.contains($0.baseUrl.path) }) else {
            throw NewArchiveStore.Error.providerNotFound
        }

        return provider
    }

    func archiveFile(from url: URL, to filename: String) throws {
        assert(!Thread.isMainThread, "This should not be called from the main thread.")

        let foldername = String(filename.prefix(4))

        guard let archiveFolder = self.archiveFolder else {
            throw NewArchiveStore.Error.providerNotFound
        }
        let documentProvider = try getProvider(for: url)
        let archiveProvider = try getProvider(for: archiveFolder)

        // check, if this path already exists ... create it
        let newFilepath = archiveFolder
            .appendingPathComponent(foldername)
            .appendingPathComponent(filename)

        if archiveProvider.baseUrl == documentProvider.baseUrl {
            try archiveProvider.rename(from: url, to: newFilepath)
        } else {
            let documentData = try documentProvider.fetch(url: url)
            try archiveProvider.save(data: documentData, at: newFilepath)
            try documentProvider.delete(url: url)
        }

        // save file tags
        if let tags = Document.parseFilename(filename).tagNames,
           !tags.isEmpty {
            newFilepath.setFileTags(tags.sorted())
        }
    }

    func startDownload(of url: URL) {
        Task.detached(priority: .userInitiated) {
            do {
                let provider = try await self.getProvider(for: url)
                try provider.startDownload(of: url)
            } catch {
                Logger.archiveStore.errorAndAssert("Failed to start download", metadata: ["error": "\(error)"])
            }
        }
    }

    func reloadArchiveDocuments() throws {
        let archiveUrl = try PathManager.shared.getArchiveUrl()
        let untaggedUrl = try PathManager.shared.getUntaggedUrl()

        #if os(macOS)
        let untaggedFolders = [untaggedUrl, UserDefaults.observedFolderURL].compactMap { $0 }
        #else
        let untaggedFolders = [untaggedUrl]
        #endif

        update(archiveFolder: archiveUrl, untaggedFolders: untaggedFolders)
    }

    private func folderDidChange(_ provider: any FolderProvider, _ changes: [FileChange]) {
        updateDocuments(with: changes)
    }

    private func updateDocuments(with fileChanges: [FileChange]) {
        do {
            for change in fileChanges {
                switch change {
                case .added(let details):
                    let downloadStatus: Double
                    switch details.downloadStatus {
                    case .downloading(percent: let percent):
                        downloadStatus = percent / 100
                    case .remote:
                        downloadStatus = 0
                    case .local:
                        downloadStatus = 1
                    }

                    guard let id = details.url.uniqueId() else {
                        Logger.archiveStore.errorAndAssert("Failed to get uniqueId")
                        continue
                    }

                    guard let filename = details.url.filename() else {
                        Logger.archiveStore.errorAndAssert("Failed to get filename")
                        continue
                    }

                    let data = Document.parseFilename(filename)
                    let isTagged = isTagged(details.url)

                    let document = Document(id: "\(id)",
                                            url: details.url,
                                            isTagged: isTagged,
                                            filename: isTagged ? filename.replacingOccurrences(of: "-", with: " ") : filename,
                                            sizeInBytes: details.sizeInBytes,
                                            date: data.date ?? details.url.fileCreationDate() ?? Date(),
                                            specification: isTagged ? (data.specification ?? "n/a").replacingOccurrences(of: "-", with: " ") : (data.specification ?? "n/a"),
                                            tags: data.tagNames ?? [],
                                            content: "",    // we write the content later on a background thread
                                            downloadStatus: downloadStatus)
                    modelContext.insert(document)

                case .removed(let url):
                    guard let id = url.uniqueId() else {
                        Logger.archiveStore.errorAndAssert("Failed to get uniqueId for delete")
                        continue
                    }

                    let predicate = #Predicate<Document> {
                        $0.id == "\(id)"
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
                        continue
                    }
                    let predicate = #Predicate<Document> {
                        $0.id == "\(id)"
                    }
                    let descriptor = FetchDescriptor<Document>(
                        predicate: predicate, sortBy: [SortDescriptor(\Document.date, order: .reverse)]
                    )
                    let documents = try modelContext.fetch(descriptor)

                    if let foundDocument = documents.first {
                        let downloadStatus: Double
                        switch details.downloadStatus {
                        case .downloading(percent: let percent):
                            downloadStatus = percent / 100
                        case .remote:
                            downloadStatus = 0
                        case .local:
                            downloadStatus = 1
                        }

                        guard let filename = details.url.filename() else {
                            Logger.archiveStore.errorAndAssert("Failed to get filename")
                            continue
                        }

                        let data = Document.parseFilename(filename)
                        if let date = data.date {
                            foundDocument.date = date
                        }
                        let isTagged = isTagged(details.url)
                        foundDocument.specification = isTagged ? (data.specification ?? "n/a").replacingOccurrences(of: "-", with: " ") : (data.specification ?? "n/a")
                        foundDocument.downloadStatus = downloadStatus

                        Logger.archiveStore.debug("Updating document", metadata: ["specification": foundDocument.specification, "downloadStatus": "\(foundDocument.downloadStatus)"])
                    }

                    for document in documents.dropFirst() {
                        modelContext.delete(document)
                    }
                }
            }

            try modelContext.save()
        } catch {
            Logger.archiveStore.errorAndAssert("Error while saving data - error: \(error)")
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
}