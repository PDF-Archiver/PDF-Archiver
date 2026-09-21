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
    public static let shared: ArchiveStore = {
        let store = ArchiveStore()
        Task(priority: .medium) {
            do {
                try await store.reloadArchiveDocuments()
            } catch {
                Logger.archiveStore.error("Failed to reload archive documents: \(LogRedact.describe(error), privacy: .public)")
            }
        }
        return store
    }()

    @Dependency(\.archiveIndexer) private var archiveIndexer

    #if os(macOS)
    @Shared(.observedFolder) var observedFolderURL: URL?
    #endif

    private static let availableProvider: [any FolderProvider.Type] = [ICloudFolderProvider.self, LocalFolderProvider.self]

    private var archiveFolder: URL!
    private var untaggedFolders: [URL] = []
    private var providers: [any FolderProvider] = []
    private var folderObservationTasks: [Task<Void, Never>] = []
    /// Counts `update()` calls: the actor suspends while it creates providers, so a second call
    /// interleaves with the first, and the superseded run must install nothing.
    private var updateCount = 0

    init() {
        Logger.archiveStore.trace("[ArchiveStore] init called")
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
        updateCount += 1
        let updateID = updateCount

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
        let newProviders = foundProviders.compactMap(\.self)

        // Resolved before the roots are announced: nothing may suspend between the generation the
        // indexer hands out and the tasks that carry it, or those tasks are born superseded.
        var observed: [(provider: any FolderProvider, rootKey: String)] = []
        for provider in newProviders {
            let rootKey = await RootKey.of(provider.baseUrl)
            observed.append((provider, rootKey))
        }

        // A newer `update()` overtook this one. Announcing these roots now would supersede *its*
        // generation, and the indexer would drop every snapshot its live tasks deliver - the
        // progress indicator then spins for the rest of the process.
        guard updateID == updateCount else {
            await Self.stop(observed.map(\.provider))
            return
        }
        let generation = await archiveIndexer.setObservedRoots(observed.map(\.rootKey))
        guard updateID == updateCount else {
            await Self.stop(observed.map(\.provider))
            return
        }

        providers = newProviders
        folderObservationTasks = observed.map { provider, rootKey in
            Task {
                let folderChangeStream = await provider.currentDocumentsStream
                for await changes in folderChangeStream {
                    guard !Task.isCancelled else { break }
                    Self.log.debug("Found documents count: \(changes.count, privacy: .public)")

                    // Only `ArchiveStore` knows `untaggedFolders`, so it stamps `isTagged` per item.
                    let items = changes.map { change -> DocumentInformation in
                        var item = change
                        item.isTagged = isTagged(change.url)
                        return item
                    }
                    await archiveIndexer.reconcile(items, rootKey, generation)
                }
            }
        }
    }

    private static func stop(_ providers: [any FolderProvider]) async {
        for provider in providers {
            await provider.stop()
        }
    }

    @FolderProviderActor
    private func initProvider(for folder: URL) -> FolderProvider? {
        guard let provider = Self.availableProvider.first(where: { $0.canHandle(folder) }) else {
            Logger.archiveStore.errorAndAssert("Could not find a FolderProvider", metadata: ["folder": "\(LogRedact.shape(folder))"])
            NotificationCenter.default.createAndPost(title: "Folder Provider Error", message: "Could not find a folder provider for path:\n\(folder.absoluteString)", primaryButtonTitle: "OK")
            return nil
        }
        Logger.archiveStore.debug("Initialize new provider for \(LogRedact.shape(folder), privacy: .public)")
        do {
            return try provider.init(baseUrl: folder)
        } catch {
            Logger.archiveStore.error("Failed to create FolderProvider - error: \(LogRedact.describe(error), privacy: .public)")
            NotificationCenter.default.postAlert(error)
            return nil
        }
    }

    private func getProvider(for url: URL) async throws -> any FolderProvider {
        for provider in providers {
            let baseUrl = await provider.baseUrl
            guard url.isUnder(baseUrl) else { continue }
            return provider
        }

        Logger.archiveStore.error("No provider found for \(LogRedact.shape(url), privacy: .public)")
        let baseUrls = await self.providers.asyncMap { await $0.baseUrl }
        Logger.archiveStore.error("Providers: \(baseUrls.count, privacy: .public)")
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
        guard !untaggedFolders.contains(where: { url.isUnder($0) }) else { return false }

        // Do "--" and "__" exist in filename?
        guard url.lastPathComponent.contains("--"),
            url.lastPathComponent.contains("__"),
            !url.lastPathComponent.lowercased().contains(Document.datePlaceholder.lowercased()),
            !url.lastPathComponent.lowercased().contains(Document.descriptionPlaceholder.lowercased()),
            !url.lastPathComponent.lowercased().contains(Document.tagPlaceholder.lowercased()) else { return false }

        return true
    }
}
