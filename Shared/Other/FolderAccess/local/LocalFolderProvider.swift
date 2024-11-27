//
//  LocalFileProvider.swift
//  
//
//  Created by Julian Kahnert on 17.08.20.
//

import DeepDiff
import Foundation

final class LocalFolderProvider: FolderProvider {

    let baseUrl: URL
    let folderChangeStream: AsyncStream<[FileChange]>
    private let folderChangeContinuation: AsyncStream<[FileChange]>.Continuation

    private let didAccessSecurityScope: Bool

    private var watcher: DirectoryDeepWatcher! = nil
    private let fileManager = FileManager.default
    private let fileProperties: [URLResourceKey] = [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey, .fileSizeKey, .localizedNameKey]

    private var currentFiles: [FileChange.Details] = []

    required init(baseUrl: URL) throws {
        self.baseUrl = baseUrl

        let (stream, continuation) = AsyncStream.makeStream(of: [FileChange].self)
        folderChangeStream = stream
        folderChangeContinuation = continuation

        self.didAccessSecurityScope = baseUrl.startAccessingSecurityScopedResource()

        Self.log.debug("Creating file provider.", metadata: ["url": "\(baseUrl.path)"])

        self.watcher = try DirectoryDeepWatcher(baseUrl, withHandler: { [weak self] _ in
            guard let self = self else { return }

            let changes = self.createChanges()
            self.folderChangeContinuation.yield(changes)
        })

        // build initial changes
        Task.detached(priority: .background) {
            let changes = await self.createChanges()
            self.folderChangeContinuation.yield(changes)
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

    private func createChanges() -> [FileChange] {
        let oldFiles = currentFiles
        let newFiles = fileManager.getFilesRecursive(at: baseUrl, with: fileProperties)
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .compactMap { url -> FileChange.Details? in

                // we do not want to track trashed files
                guard !url.pathComponents.contains(".Trash") else { return nil }

                guard let resourceValues = try? url.resourceValues(forKeys: Set(fileProperties)),
                      let fileSize = resourceValues.fileSize else {
                    log.errorAndAssert("Could not fetch resource values from url.", metadata: ["url": "\(url.path)"])
                    return nil
                }

                let downloadStatus = getDownloadStatus(from: resourceValues)
                return FileChange.Details(url: url, sizeInBytes: Double(fileSize), downloadStatus: downloadStatus)
            }
            .sorted { $0.url.path < $1.url.path }

        currentFiles = newFiles

        return diff(old: oldFiles, new: newFiles)
            .flatMap { change -> [FileChange] in
                switch change {
                    case .insert(let insertDetails):
                        return [.added(insertDetails.item)]
                    case .delete(let deleteDetails):
                        return [.removed(deleteDetails.item.url)]
                    case .replace(let replaceDetails):
                        return [.removed(replaceDetails.oldItem.url), .added(replaceDetails.newItem)]
                    case .move:
                        assertionFailure("This should not happen, since we sort the document by path.")
                        // we are not interested in moved documents
                        return []
                }
            }
    }

    private func getDownloadStatus(from values: URLResourceValues) -> FileChange.DownloadStatus {
        let downloadStatus: FileChange.DownloadStatus
        if values.ubiquitousItemIsDownloading ?? false {
            downloadStatus = .downloading(percent: 0.123)
        } else if values.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.notDownloaded {
            downloadStatus = .remote
        } else {
            downloadStatus = .local
        }
        return downloadStatus
    }
}
