//
//  LocalFileProvider.swift
//  
//
//  Created by Julian Kahnert on 17.08.20.
//

import Foundation

final class LocalFolderProvider: FolderProvider {

    let baseUrl: URL
    let currentDocumentsStream: AsyncStream<[DocumentInformation]>
    private let currentDocumentsStreamContinuation: AsyncStream<[DocumentInformation]>.Continuation

    private let didAccessSecurityScope: Bool

    private let watcher: DirectoryDeepWatcher
    private let fileManager = FileManager.default
    private let fileProperties: [URLResourceKey] = [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey, .fileSizeKey, .localizedNameKey]

    required init(baseUrl: URL) throws {
        self.baseUrl = baseUrl

        let (stream, continuation) = AsyncStream.makeStream(of: [DocumentInformation].self)
        currentDocumentsStream = stream
        currentDocumentsStreamContinuation = continuation

        self.didAccessSecurityScope = baseUrl.startAccessingSecurityScopedResource()

        Self.log.debug("Creating file provider.", metadata: ["url": "\(baseUrl.path)"])

        self.watcher = try DirectoryDeepWatcher(at: baseUrl)

        Task(priority: .background) {
            // build initial changes
            let documents = await self.createDocuments()
            self.currentDocumentsStreamContinuation.yield(documents)

            // listen to changes in folder
            for await _ in self.watcher.changedUrlStream {
                let documents = await self.createDocuments()
                self.currentDocumentsStreamContinuation.yield(documents)
            }
        }
    }

    deinit {
        guard didAccessSecurityScope else { return }
        baseUrl.stopAccessingSecurityScopedResource()
    }

    // MARK: - API

    static func canHandle(_ url: URL) -> Bool {
        // we must add the security scope here, because the LocalFolderProvider is not initialized when this functions gets called
        url.securityScope {
            FileManager.default.isReadableFile(atPath: $0.path) &&
                FileManager.default.isWritableFile(atPath: $0.path)
        }
    }

    func save(data: Data, at url: URL) throws {
        try fileManager.createFolderIfNotExists(url.deletingLastPathComponent())

        // test if the document name already exists in archive, otherwise move it
        if fileManager.fileExists(atPath: url.path) {
            throw FolderProviderError.renameFailedFileAlreadyExists
        }

        try data.write(to: url)
    }

    func startDownload(of url: URL) throws {
        log.errorAndAssert("Download of a local file is not supported")
    }

    func fetch(url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func delete(url: URL) throws {
        #if os(macOS)
        try fileManager.trashItem(at: url, resultingItemURL: nil)
        #else
        // trash is not possible for local documents on iOS
        // => document appears again after relaunch
        // => we have to use removeItem on iOS
        try fileManager.removeItem(at: url)
        #endif
    }

    func rename(from source: URL, to destination: URL) throws {
        guard source != destination else { return }
        try fileManager.createFolderIfNotExists(destination.deletingLastPathComponent())

        // test if the document name already exists in archive, otherwise move it
        if fileManager.fileExists(atPath: destination.path) {
            throw FolderProviderError.renameFailedFileAlreadyExists
        }

        try fileManager.moveItem(at: source, to: destination)
    }

    // MARK: - Helper Functions

    private func createDocuments() async -> [DocumentInformation] {
        return fileManager.getFilesRecursive(at: baseUrl, with: fileProperties)
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .compactMap { url -> DocumentInformation? in

                // we do not want to track trashed files
                guard !url.pathComponents.contains(".Trash") else { return nil }

                guard let resourceValues = try? url.resourceValues(forKeys: Set(fileProperties)),
                      let fileSize = resourceValues.fileSize else {
                    log.errorAndAssert("Could not fetch resource values from url.", metadata: ["url": "\(url.path)"])
                    return nil
                }

                let downloadStatus = getDownloadStatus(from: resourceValues)
                return DocumentInformation(url: url, downloadStatus: downloadStatus, sizeInBytes: Double(fileSize))
            }
            .sorted { $0.url.path < $1.url.path }
    }

    private func getDownloadStatus(from values: URLResourceValues) -> Double {
        let downloadStatus: Double
        if values.ubiquitousItemIsDownloading ?? false {
            downloadStatus = 0.123
        } else if values.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.notDownloaded {
            // remote
            downloadStatus = 0
        } else {
            // local
            downloadStatus = 1
        }
        return downloadStatus
    }
}
