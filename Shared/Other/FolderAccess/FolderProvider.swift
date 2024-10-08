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
protocol FolderProvider: AnyObject, Log {
    typealias FolderChangeHandler = (any FolderProvider, [FileChange]) -> Void

    static func canHandle(_ url: URL) -> Bool

    nonisolated
    var baseUrl: URL { get }

    init(baseUrl: URL, _ handler: @escaping FolderChangeHandler) throws

    func save(data: Data, at: URL) throws
    func startDownload(of: URL) throws
    func fetch(url: URL) throws -> Data
    func delete(url: URL) throws
    func rename(from: URL, to: URL) throws
}
