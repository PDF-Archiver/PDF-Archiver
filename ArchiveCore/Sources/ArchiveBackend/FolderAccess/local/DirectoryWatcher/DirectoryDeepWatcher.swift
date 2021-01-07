//
//  DirectoryDeepWatcher.swift
//  DirectoryWatcher
//
//  Created by Gianni Carlo on 3/18/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import Foundation

final class DirectoryDeepWatcher: NSObject, Log {

    typealias FolderChangeHandler = (URL) -> Void
    private typealias SourceObject = (source: DispatchSourceFileSystemObject, descriptor: Int32, url: URL)

    private static let queue = DispatchQueue.global(qos: .background)
    private static var folderChangeHandler: FolderChangeHandler?

    private var watchedUrl: URL
    private var sources = [SourceObject]()

    private init(watchedUrl: URL) {
        self.watchedUrl = watchedUrl
    }

    deinit {
        stopWatching()
    }

    static func watch(_ url: URL, withHandler handler: @escaping FolderChangeHandler) -> DirectoryDeepWatcher? {
        folderChangeHandler = handler
        let directoryWatcher = DirectoryDeepWatcher(watchedUrl: url)

        guard let sourceObject = directoryWatcher.createSource(from: url) else { return nil }
        directoryWatcher.sources.append(sourceObject)

        let enumerator = FileManager.default.enumerator(at: url,
                                                        includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
                                                        options: [.skipsHiddenFiles]) { (url, error) -> Bool in
            log.criticalAndAssert("Directory enumerator error", metadata: ["error": "\(error)", "url": "\(url.path)"])
            return true
        }

        guard let tmpEnumerator = enumerator,
              directoryWatcher.startWatching(with: tmpEnumerator) else {
            // Something went wrong, return nil
            return nil
        }

        return directoryWatcher
    }

    private func createSource(from url: URL) -> SourceObject? {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else { return nil }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: Self.queue)

        source.setEventHandler { [weak self] in
            Self.folderChangeHandler?(url)

            let enumerator = FileManager.default.enumerator(at: url,
                                                            includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey])

            guard let safeEnumerator = enumerator else { preconditionFailure("Failed to create enumerator.") }
            _ = self?.startWatching(with: safeEnumerator)
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.resume()

        return (source, descriptor, url)
    }

    private func startWatching(with enumerator: FileManager.DirectoryEnumerator) -> Bool {
        guard let url = enumerator.nextObject() as? URL else { return true }

        if !url.hasDirectoryPath {
            return startWatching(with: enumerator)
        }

        if sources.contains(where: { $0.url == url }) {
            return startWatching(with: enumerator)
        }

        guard let sourceObject = createSource(from: url) else { return false }

        sources.append(sourceObject)

        return startWatching(with: enumerator)
    }

    func stopWatching() {
        for sourceObject in sources {
            sourceObject.source.cancel()
        }

        sources.removeAll()
    }
}
