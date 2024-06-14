//
//  DirectoryDeepWatcher.swift
//
//  Created by Julian Kahnert on 06.02.21.
//
// Inspired by: https://github.com/GianniCarlo/DirectoryWatcher

import Foundation

final class DirectoryDeepWatcher: Log {

    typealias FolderChangeHandler = (URL) -> Void
    private typealias SourceObject = (source: any DispatchSourceFileSystemObject, descriptor: Int32)

    let baseUrl: URL
    private let queue = DispatchQueue(label: "DirectoryDeepWatcher \(UUID().uuidString)", qos: .background)
    private let folderChangeHandler: FolderChangeHandler
    private var sources = [URL: SourceObject]()

    init(_ baseUrl: URL, withHandler handler: @escaping FolderChangeHandler) throws {
        self.baseUrl = baseUrl
        self.folderChangeHandler = handler

        Self.log.debug("Creating new directory watcher.", metadata: ["path": "\(baseUrl.path)"])

        do {
            // create source for the parent directory
            try createAndAddSource(from: baseUrl)

            // We have to startWatching an the queue, because during the initial creating of all sources
            // one folder (e.g. the first) might be changed, which triggers the event handler on the queue.
            // By syncing these calls on a serial queue, they will be processed one after another.
            try queue.sync {
                try startWatching(contentsOf: baseUrl)
            }
        } catch {
            log.error("Failed to create DirectoryDeepWatcher", metadata: ["error": "\(error)"])
            throw error
        }
    }

    deinit {
        sources.forEach { $0.value.source.cancel() }
        sources.removeAll()
    }

    private func createAndAddSource(from url: URL) throws {

        // no need to create a second source
        guard sources[url] == nil else { return }

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else { throw WatcherError.failedToCreateFileDescriptor }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: queue)
        source.setEventHandler { [weak self] in
            self?.folderChangeHandler(url)

            Self.log.debug("DispatchSource event has happened.", metadata: ["path": "\(url.path)"])
            do {
                // iterate (once again) over all folders and subfolders, to get all changes
                try self?.startWatching(contentsOf: url)
            } catch {
                Self.log.error("Failed to start watching in event handler", metadata: ["error": "\(error)"])
            }
        }

        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()

        // add new source to the source dictionary
        sources[url] = (source, descriptor)
    }

    private func startWatching(contentsOf url: URL) throws {
        let enumerator = FileManager.default.enumerator(at: url,
                                                        includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
                                                        options: [.skipsHiddenFiles]) { (url, error) -> Bool in
            // if a folder was deleted during enumeration, there occurs a "no such file" error - we assume that there will be another change triggered
            guard (error as NSError).code != NSFileReadNoSuchFileError else { return false }

            Self.log.criticalAndAssert("Directory enumerator error", metadata: ["error": "\(error)", "url": "\(url.path)"])
            return true
        }
        guard let safeEnumerator = enumerator else { throw WatcherError.failedToCreateEnumerator }

        log.trace("Iterating and creating sources if needed.", metadata: ["path": "\(url.absoluteString)"])
        for case let url as URL in safeEnumerator {
            guard url.hasDirectoryPath else { continue }

            try createAndAddSource(from: url)
        }
    }

    private enum WatcherError: Error {
        case failedToCreateEnumerator
        case failedToCreateFileDescriptor
    }
}
