//
//  DirectoryDeepWatcher.swift
//
//  Created by Julian Kahnert on 06.02.21.
//
// Inspired by: https://github.com/GianniCarlo/DirectoryWatcher

import Foundation
import Shared

actor DirectoryDeepWatcher: Log {
    let baseUrl: URL
    let changedUrlStream: AsyncStream<URL>
    private let changedUrlContinuation: AsyncStream<URL>.Continuation
    private let queue: DispatchQueue

    private var sources: [URL: (DispatchSourceWatcher, Task<Void, Never>)] = [:]

    init(at baseUrl: URL) throws {
        self.baseUrl = baseUrl

        let (stream, continuantion) = AsyncStream<URL>.makeStream()
        self.changedUrlStream = stream
        self.changedUrlContinuation = continuantion

        self.queue = DispatchQueue(label: "DirectoryDeepWatcher-\(baseUrl.hashValue)", qos: .background)

        Task {
            try await initializeWatcher()
        }
    }

    deinit {
        Task { [sources] in
            for (_, source) in sources {
                source.1.cancel()
                await source.0.cancel()
            }
        }
        sources.removeAll()
    }

    func stop() async {
        for (_, source) in sources {
            source.1.cancel()
            await source.0.cancel()
        }

        sources.removeAll()
    }

    private func initializeWatcher() async throws {
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

    private func createAndAddSource(from url: URL) throws {
        // no need to create a second source
        guard sources[url] == nil else { return }

        let watcher = try DispatchSourceWatcher(queue: queue, url: url)
        let task = Task { [weak self] in
            for await url in watcher.changedUrlStream {
                guard let self,
                      !Task.isCancelled else { return }
                self.changedUrlContinuation.yield(url)

                Self.log.debug("DispatchSource event has happened.", metadata: ["path": "\(url.path)"])
                do {
                    // iterate (once again) over all folders and subfolders, to get all changes
                    try await self.startWatching(contentsOf: url)
                } catch {
                    Self.log.error("Failed to start watching in event handler", metadata: ["error": "\(error)"])
                }
            }
        }

        // add new source to the source dictionary
        sources[url] = (watcher, task)
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

extension DirectoryDeepWatcher {
    private actor DispatchSourceWatcher: Log {
        let url: URL
        let changedUrlStream: AsyncStream<URL>
        private let source: DispatchSourceFileSystemObject

        init(queue: DispatchQueue, url: URL) throws {
            self.url = url

            let (stream, continuantion) = AsyncStream<URL>.makeStream()
            self.changedUrlStream = stream

            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor != -1 else { throw WatcherError.failedToCreateFileDescriptor }

            source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: [.write, .rename, .delete],
                                                               queue: queue)
            source.setEventHandler {
                continuantion.yield(url)
            }

            source.setCancelHandler {
                close(descriptor)
            }
            source.resume()
        }

        func cancel() {
            source.cancel()
        }
    }
}
