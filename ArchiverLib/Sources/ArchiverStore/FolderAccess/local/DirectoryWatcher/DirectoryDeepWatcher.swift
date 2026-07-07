//
//  DirectoryDeepWatcher.swift
//
//  Created by Julian Kahnert on 06.02.21.
//
// Inspired by: https://github.com/GianniCarlo/DirectoryWatcher

import Foundation
import OSLog
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
            do {
                try await initializeWatcher()
            } catch {
                Logger.archiveStore.error("Failed to initialize watcher: \(error.localizedDescription)")
            }
        }
    }

    // No deinit needed: releasing the actor releases `sources`, each
    // DispatchSourceWatcher cancels itself in its deinit (closing the file
    // descriptor), and the finished streams end the observation tasks.

    func stop() {
        for (_, source) in sources {
            source.1.cancel()
            source.0.cancel()
        }

        sources.removeAll()
    }

    private func initializeWatcher() throws {
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
        // Capture only the Sendable stream - the watcher itself is non-Sendable
        // state confined to this actor.
        let changedUrlStream = watcher.changedUrlStream
        let task = Task { [weak self] in
            for await url in changedUrlStream {
                guard let self,
                      !Task.isCancelled else { return }
                changedUrlContinuation.yield(url)

                Self.log.debug("DispatchSource event has happened.", metadata: ["path": "\(url.path)"])

                // remove watchers of deleted folders, so a recreated folder with the same path gets a fresh source
                await removeStaleSources()

                do {
                    // iterate (once again) over all folders and subfolders, to get all changes
                    try await startWatching(contentsOf: url)
                } catch {
                    Self.log.error("Failed to start watching in event handler", metadata: ["error": "\(error)"])
                }
            }
        }

        // add new source to the source dictionary
        sources[url] = (watcher, task)
    }

    /// Cancel and remove sources whose folder no longer exists.
    ///
    /// Without this, the file descriptor of a deleted folder would keep pointing to the dead
    /// inode and the `sources[url] == nil` guard in `createAndAddSource` would prevent a new
    /// source from being created when a folder is recreated at the same path.
    private func removeStaleSources() {
        for (url, source) in sources where !FileManager.default.directoryExists(at: url) {
            source.1.cancel()
            source.0.cancel()
            sources[url] = nil
        }
    }

    private func startWatching(contentsOf url: URL) throws {
        let enumerator = FileManager.default.enumerator(at: url,
                                                        includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
                                                        options: [.skipsHiddenFiles]) { url, error -> Bool in
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
    // A class (not an actor), so `cancel()` can run synchronously from `deinit`.
    // Deliberately not Sendable: instances are confined to the DirectoryDeepWatcher
    // actor; only the Sendable `changedUrlStream` is shared with the observation task.
    private final class DispatchSourceWatcher {
        let changedUrlStream: AsyncStream<URL>
        private let changedUrlContinuation: AsyncStream<URL>.Continuation
        private let source: DispatchSourceFileSystemObject

        init(queue: DispatchQueue, url: URL) throws {
            let (stream, continuation) = AsyncStream<URL>.makeStream()
            self.changedUrlStream = stream
            self.changedUrlContinuation = continuation

            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor != -1 else { throw WatcherError.failedToCreateFileDescriptor }

            source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: [.write, .rename, .delete],
                                                               queue: queue)
            source.setEventHandler {
                continuation.yield(url)
            }

            // the cancel handler closes the file descriptor, so cancel() must always be called
            source.setCancelHandler {
                close(descriptor)
            }
            source.resume()
        }

        deinit {
            cancel()
        }

        func cancel() {
            source.cancel()
            changedUrlContinuation.finish()
        }
    }
}
