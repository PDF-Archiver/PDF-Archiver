//
//  FolderProvider.swift
//  
//
//  Created by Julian Kahnert on 16.08.20.
//

import Foundation

@globalActor actor FolderProviderActor: GlobalActor {
    static let shared = FolderProviderActor()
}

@FolderProviderActor
protocol FolderProvider: AnyObject, Log, Sendable {

    static func canHandle(_ url: URL) -> Bool

    // this is a constant, not sure how to declare it in the protocol
    nonisolated
    var baseUrl: URL { get }
    var folderChangeStream: AsyncStream<[FileChange]> { get }

    init(baseUrl: URL) throws

    func save(data: Data, at: URL) throws
    func startDownload(of: URL) throws
    func fetch(url: URL) throws -> Data
    func delete(url: URL) throws
    func rename(from: URL, to: URL) throws
}
