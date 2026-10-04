//
//  FolderProvider.swift
//  
//
//  Created by Julian Kahnert on 16.08.20.
//

import ArchiverDatabase
import ArchiverModels
import Foundation
import Shared

@globalActor actor FolderProviderActor: GlobalActor {
    static let shared = FolderProviderActor()
}

@FolderProviderActor
protocol FolderProvider: AnyObject, Log, Sendable {

    static func canHandle(_ url: URL) -> Bool

    // this is a constant, not sure how to declare it in the protocol
    var baseUrl: URL { get }
    var currentDocumentsStream: AsyncStream<[DocumentInformation]> { get }

    init(baseUrl: URL) throws

    func stop()

    func save(data: Data, at: URL) throws
    func fetch(url: URL) throws -> Data
    func delete(url: URL) throws
    func rename(from: URL, to: URL) throws
}

extension FolderProvider {
    func save(data: Data, at url: URL) throws {
        try FileManager.default.createFolderIfNotExists(url.deletingLastPathComponent())
        try ensureNothingExists(at: url)
        try data.write(to: url)
    }

    func fetch(url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func rename(from source: URL, to destination: URL) throws {
        guard source != destination else { return }
        try FileManager.default.createFolderIfNotExists(destination.deletingLastPathComponent())
        try ensureNothingExists(at: destination)
        try FileManager.default.moveItem(at: source, to: destination)
    }

    /// An evicted iCloud document exists only as its `.name.icloud` placeholder and is still part
    /// of the archive, so a plain `fileExists` would let a rename move over it.
    private func ensureNothingExists(at url: URL) throws {
        if ArchiveIndexer.fileOrPlaceholderExists(url) {
            throw FolderProviderError.renameFailedFileAlreadyExists
        }
    }
}
