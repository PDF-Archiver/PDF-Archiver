//
//  DemoFileProvider.swift
//  
//
//  Created by Julian Kahnert on 08.01.21.
//
// swiftlint:disable force_unwrapping

import Foundation

final class DemoFolderProvider: FolderProvider, Log {
    private static var isInitialized = false
    static func canHandle(_ url: URL) -> Bool {
        true
    }

    var baseUrl: URL
    private var handler: FolderChangeHandler

    init(baseUrl: URL, _ handler: @escaping FolderChangeHandler) throws {
        self.baseUrl = baseUrl
        self.handler = handler

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
        handler(self, urls.map { FileChange.added(.init(fileUrl: $0)) })
    }
}

private enum DemoFolderProviderError: String, Error {
    case alreadyInitialized
}
