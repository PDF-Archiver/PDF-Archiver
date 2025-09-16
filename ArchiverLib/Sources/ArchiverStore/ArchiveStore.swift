//
//  ArchiveStore.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import ArchiverModels
import AsyncExtensions
import Sharing
import Foundation
import OSLog
import PDFKit.PDFDocument
import Shared

public actor ArchiveStore: Log {
    public static let shared = ArchiveStore()

    #if os(macOS)
    @Shared(.observedFolder) var observedFolderURL: URL?
    #endif

    #if DEBUG
    private static let availableProvider: [any FolderProvider.Type] = {
        if UserDefaults.standard.bool(forKey: "demoMode") {
            return [DemoFolderProvider.self]
        } else {
            return [ICloudFolderProvider.self, LocalFolderProvider.self]
        }
    }()
    #else
    private static let availableProvider: [any FolderProvider.Type] = [ICloudFolderProvider.self, LocalFolderProvider.self]
    #endif

    public let isLoadingStream = AsyncCurrentValueSubject(true)
    public let documentsStream: AsyncStream<[Document]>
    private let documentsStreamContinuation: AsyncStream<[Document]>.Continuation
    public private(set) var currentDocuments: [Document] = []

    private var archiveFolder: URL!
    private var untaggedFolders: [URL] = []
    private var providers: [any FolderProvider] = []
    private var folderObservationTasks: [Task<Void, Never>] = []
    // Since we run a full sync at startup, we have to remove all old documents initially.
    private var removeOldDocumentsInNextSync = true

    private init() {
        let (stream, continuation) = AsyncStream<[Document]>.makeStream()
        self.documentsStream = stream
        self.documentsStreamContinuation = continuation

        Logger.archiveStore.trace("[ArchiveStore] init called")

        Task(priority: .medium) {
            try await reloadArchiveDocuments()
        }
    }

    public func update(with type: StorageType) async throws {
        try await PathManager.shared.setArchiveUrl(with: type)

        let archiveUrl = try await PathManager.shared.getArchiveUrl()
        let untaggedUrl = try await PathManager.shared.getUntaggedUrl()

        await ArchiveStore.shared.update(archiveFolder: archiveUrl, untaggedFolders: [untaggedUrl])
    }

    public func getUntaggedUrl() async throws -> URL {
        try await PathManager.shared.getArchiveUrl()
    }

    func update(archiveFolder: URL, untaggedFolders: [URL]) async {
        isLoadingStream.send(true)

        // remove all current file providers to prevent watching changes while moving folders
        providers = []
        folderObservationTasks.forEach { $0.cancel() }
        folderObservationTasks = []

        self.archiveFolder = archiveFolder
        self.untaggedFolders = untaggedFolders
        let observedFolders = await [[archiveFolder], untaggedFolders]
            .flatMap { $0 }
            .getUniqueParents()
        var foundProviders: [(any FolderProvider)?] = []
        for observedFolder in observedFolders {
            let provider = await initProvider(for: observedFolder)
            foundProviders.append(provider)
        }
        providers = foundProviders.compactMap { $0 }
        var documentsMap: [URL: [Document]] = [:]
        for provider in providers {
            let task = Task {
                let folderChangeStream = await provider.currentDocumentsStream
                for await changes in folderChangeStream {
                    Self.log.debug("Found documents count: \(changes.count)")

                    await documentsMap[provider.baseUrl] = changes.asyncMap { change in
                        await Document.create(url: change.url,
                                        isTagged: isTagged(change.url),
                                        downloadStatus: change.downloadStatus,
                                        sizeInBytes: change.sizeInBytes)
                    }
                    .compactMap { $0 }

                    let documents = documentsMap.values.flatMap(\.self)
                    documentsStreamContinuation.yield(documents)
                    currentDocuments = documents
                    isLoadingStream.send(false)
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
            try await newFilepath.setFileTags(document.tags.sorted())
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

    /// Returns tags that where used similarly on tagged documents
    public func getTagSuggestionsSimilar(to tags: Set<String>) -> [String] {
        guard !tags.isEmpty else { return [] }
        let filteredTagCombinations = currentDocuments
            .map(\.tags)
            .filter { $0.isSuperset(of: tags) }

        var tagCountMap: [String: Int] = [:]
        for tag in filteredTagCombinations.flatMap(\.self) {
            guard !tags.contains(tag) else { continue }
            tagCountMap[tag, default: 0] += 1
        }

        let top5Tags = tagCountMap
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    lhs.key < rhs.key
                } else {
                    lhs.value > rhs.value
                }
            }
            .prefix(5)
            .map(\.key)

        return top5Tags
    }

    /// Returns tags that start with the searchteerm like autocomplete
    ///
    /// The returned tag will be sorted according to their usage count.
    ///
    /// - `bi` -> `[bill]`
    public func getTagSuggestions(for searchTerm: String) -> [String] {
        var tagCountMap: [String: Int] = [:]
        for tag in currentDocuments.flatMap(\.tags) {
            tagCountMap[tag, default: 0] += 1
        }
        let top5Tags = tagCountMap
            .filter { $0.key.hasPrefix(searchTerm) }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    lhs.key < rhs.key
                } else {
                    lhs.value > rhs.value
                }
            }
            .prefix(5)
            .map(\.key)
        return top5Tags
    }

    public func reloadArchiveDocuments() async throws {
        folderObservationTasks.forEach { $0.cancel() }
        folderObservationTasks.removeAll()

        let archiveUrl = try await PathManager.shared.getArchiveUrl()
        let untaggedUrl = try await PathManager.shared.getUntaggedUrl()

        #if os(macOS)
        #warning("TODO: test this")
        let untaggedFolders = [untaggedUrl, observedFolderURL].compactMap { $0 }
        #else
        let untaggedFolders = [untaggedUrl]
        #endif

        removeOldDocumentsInNextSync = true
        await update(archiveFolder: archiveUrl, untaggedFolders: untaggedFolders)
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
