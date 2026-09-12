//
//  ArchiveStore.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import ArchiverDatabase
import ArchiverModels
import Dependencies
import Foundation
import OSLog
import PDFKit.PDFDocument
import Shared
import Sharing

public actor ArchiveStore: Log {
    public static let shared = ArchiveStore()

    @Dependency(\.archiveIndexer) private var archiveIndexer

    #if os(macOS)
    @Shared(.observedFolder) var observedFolderURL: URL?
    #endif

    private static let availableProvider: [any FolderProvider.Type] = [ICloudFolderProvider.self, LocalFolderProvider.self]

    private var archiveFolder: URL!
    private var untaggedFolders: [URL] = []
    private var providers: [any FolderProvider] = []
    private var folderObservationTasks: [Task<Void, Never>] = []

    private init() {
        Logger.archiveStore.trace("[ArchiveStore] init called")

        Task(priority: .medium) {
            do {
                try await reloadArchiveDocuments()
            } catch {
                Logger.archiveStore.error("Failed to reload archive documents: \(error.localizedDescription)")
            }
        }
    }

    public func update(with type: StorageType) async throws {
        try await PathManager.shared.setArchiveUrl(with: type)

        let archiveUrl = try await PathManager.shared.getArchiveUrl()
        let untaggedUrl = try await PathManager.shared.getUntaggedUrl()

        await update(archiveFolder: archiveUrl, untaggedFolders: [untaggedUrl])
    }

    public func getUntaggedUrl() async throws -> URL {
        try await PathManager.shared.getUntaggedUrl()
    }

    func update(archiveFolder: URL, untaggedFolders: [URL]) async {
        // stop all current file providers to prevent watching changes while moving folders
        for provider in providers {
            await provider.stop()
        }
        providers = []
        folderObservationTasks.forEach { $0.cancel() }
        folderObservationTasks = []

        self.archiveFolder = archiveFolder
        self.untaggedFolders = untaggedFolders
        let observedFolders = [[archiveFolder], untaggedFolders]
            .flatMap(\.self)
            .getUniqueParents()
        var foundProviders: [(any FolderProvider)?] = []
        for observedFolder in observedFolders {
            let provider = await initProvider(for: observedFolder)
            foundProviders.append(provider)
        }
        providers = foundProviders.compactMap(\.self)

        var rootKeys: [URL: String] = [:]
        for provider in providers {
            await rootKeys[provider.baseUrl] = RootKey.of(provider.baseUrl)
        }
        let generation = await archiveIndexer.setObservedRoots(Array(rootKeys.values))

        for provider in providers {
            let baseUrl = await provider.baseUrl
            guard let rootKey = rootKeys[baseUrl] else { continue }
            let task = Task {
                let folderChangeStream = await provider.currentDocumentsStream
                for await changes in folderChangeStream {
                    guard !Task.isCancelled else { break }
                    Self.log.debug("Found documents count: \(changes.count)")

                    // Only `ArchiveStore` knows `untaggedFolders`, so it stamps `isTagged` per item.
                    let items = changes.map { change in
                        DocumentSnapshotItem(id: change.id,
                                             url: change.url,
                                             isTagged: isTagged(change.url),
                                             sizeInBytes: change.sizeInBytes,
                                             downloadStatus: change.downloadStatus,
                                             creationDate: change.creationDate,
                                             contentModificationDate: change.contentModificationDate)
                    }
                    await archiveIndexer.reconcile(items, rootKey, generation)
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

    public func save(_ document: Document, shouldUpdatePdfMetadata: Bool) async throws {
        let url = document.url
        let filename = Document.createFilename(date: document.date, specification: document.specification, tags: document.tags)

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
        if shouldUpdatePdfMetadata,
           !document.tags.isEmpty {
            let tags = document.tags.sorted()

            // write pdf metadata
            if let pdfDocument = PDFDocument(url: newFilepath) {
                var attributes = pdfDocument.documentAttributes ?? [:]
                attributes[PDFDocumentAttribute.keywordsAttribute] = tags
                pdfDocument.documentAttributes = attributes

                pdfDocument.write(to: newFilepath)
            }

            // write finder tags
            try await newFilepath.setFileTags(tags)
        }
    }

    public func startDownload(of url: URL) async throws {
        let provider = try await getProvider(for: url)
        try await provider.startDownload(of: url)
    }

    public func delete(url: URL) async throws {
        let provider = try await getProvider(for: url)
        try await provider.delete(url: url)
    }

    public func reloadArchiveDocuments() async throws {
        folderObservationTasks.forEach { $0.cancel() }
        folderObservationTasks.removeAll()

        let archiveUrl = try await PathManager.shared.getArchiveUrl()
        let untaggedUrl = try await PathManager.shared.getUntaggedUrl()

        #if os(macOS)
        let untaggedFolders = [untaggedUrl, observedFolderURL].compactMap(\.self)
        #else
        let untaggedFolders = [untaggedUrl]
        #endif

        await update(archiveFolder: archiveUrl, untaggedFolders: untaggedFolders)
    }

    private func isTagged(_ url: URL) -> Bool {

        // Could document be found in the untagged folder?
        guard !untaggedFolders.contains(where: { url.path.contains($0.path) }) else { return false }

        // Do "--" and "__" exist in filename?
        guard url.lastPathComponent.contains("--"),
            url.lastPathComponent.contains("__"),
            !url.lastPathComponent.lowercased().contains(Document.datePlaceholder.lowercased()),
            !url.lastPathComponent.lowercased().contains(Document.descriptionPlaceholder.lowercased()),
            !url.lastPathComponent.lowercased().contains(Document.tagPlaceholder.lowercased()) else { return false }

        return true
    }
}
