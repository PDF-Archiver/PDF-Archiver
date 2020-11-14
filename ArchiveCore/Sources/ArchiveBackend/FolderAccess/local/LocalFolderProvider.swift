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
    private let folderDidChange: FolderChangeHandler

    private let watcher: DirectoryDeepWatcher
    private let fileManager = FileManager.default
    private let fileProperties: [URLResourceKey] = [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey, .fileSizeKey, .localizedNameKey]

    private var currentFiles: [FileChange.Details] = []

    required init(baseUrl: URL, _ handler: @escaping (FolderProvider, [FileChange]) -> Void) {
        self.baseUrl = baseUrl
        self.folderDidChange = handler

        guard let watcher = DirectoryDeepWatcher.watch(baseUrl) else {
            preconditionFailure("Could not create local watcher.")
        }
        self.watcher = watcher
        watcher.onFolderNotification = { [weak self] _ in
            guard let self = self else { return }

            let changes = self.createChanges()
            self.folderDidChange(self, changes)
        }

        DispatchQueue.global(qos: .background).async {
            // build initial changes
            let changes = self.createChanges()
            self.folderDidChange(self, changes)
        }
    }

    // MARK: - API

    static func canHandle(_ url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path) &&
            FileManager.default.isWritableFile(atPath: url.path)
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
        try fileManager.removeItem(at: url)
    }

    func rename(from source: URL, to destination: URL) throws {
        try fileManager.createFolderIfNotExists(destination.deletingLastPathComponent())

        // test if the document name already exists in archive, otherwise move it
        if fileManager.fileExists(atPath: destination.path) {
            throw FolderProviderError.renameFailedFileAlreadyExists
        }

        try fileManager.moveItem(at: source, to: destination)
    }

    func getCreationDate(of url: URL) throws -> Date? {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.creationDate] as? Date
    }

    // MARK: - Helper Functions

    private func createChanges() -> [FileChange] {
        let oldFiles = currentFiles
        let newFiles = baseUrl.getFilesRecursive(fileProperties: fileProperties)
            .compactMap { url -> FileChange.Details? in

                guard let resourceValues = try? url.resourceValues(forKeys: Set(fileProperties)),
                      let fileSize = resourceValues.fileSize else {
                    log.errorAndAssert("Could not fetch resource values from url.", metadata: ["url": "\(url.path)"])
                    return nil
                }

                let downloadStatus = getDownloadStatus(from: resourceValues)
                let filename: String
                if downloadStatus == .local {
                    filename = url.deletingPathExtension().lastPathComponent
                } else if let localizedName = resourceValues.localizedName {
                    filename = localizedName
                } else {
                    log.errorAndAssert("Filename could not be fetched.", metadata: ["url": "\(url.path)"])
                    return nil
                }

                return FileChange.Details(url: url, filename: filename, size: fileSize, downloadStatus: downloadStatus)
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
