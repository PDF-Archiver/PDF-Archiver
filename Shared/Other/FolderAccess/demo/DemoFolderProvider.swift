//
//  DemoFileProvider.swift
//  
//
//  Created by Julian Kahnert on 08.01.21.
//
// swiftlint:disable force_unwrapping

import AsyncAlgorithms
import Foundation

#if DEBUG
final class DemoFolderProvider: FolderProvider, Log {
    private static var isInitialized = false
    static func canHandle(_ url: URL) -> Bool {
        true
    }

    let baseUrl: URL
    let folderChangeStream = AsyncChannel<[FileChange]>()

    init(baseUrl: URL) throws {
        self.baseUrl = baseUrl

        guard !Self.isInitialized,
              baseUrl.lastPathComponent != "untagged" else { throw DemoFolderProviderError.alreadyInitialized }
        initialize()
        Self.isInitialized = true
    }

    func save(data: Data, at: URL) throws {
        log.debug("save(data: Data, at: URL) throws")
    }

    func startDownload(of: URL) throws {
        log.debug("startDownload(of: URL) throws")
    }

    func fetch(url: URL) throws -> Data {
        log.debug("fetch(url: URL) throws -> Data")
        return Data()
    }

    func delete(url: URL) throws {
        log.debug("delete(url: URL) throws")
    }

    func rename(from: URL, to: URL) throws {
        log.debug("rename(from: URL, to: URL) throws")
    }

    private func initialize() {
        let url = Bundle.main.url(forResource: "example-bill", withExtension: "pdf")!
        let destination = baseUrl.appendingPathComponent("untagged").appendingPathComponent("2021 01 08 - scan1.pdf")
        try? FileManager.default.copyItem(at: url, to: destination)

        let urls = [
            baseUrl.appendingPathComponent(NSLocalizedString("test_file1", comment: "")),
            baseUrl.appendingPathComponent(NSLocalizedString("test_file2", comment: "")),
            baseUrl.appendingPathComponent(NSLocalizedString("test_file3", comment: "")),
            destination
        ]
        Task {
            await folderChangeStream.send(urls.map { FileChange.added(.init(fileUrl: $0)) })
        }
    }
}

private enum DemoFolderProviderError: String, Error {
    case alreadyInitialized
}
#endif
