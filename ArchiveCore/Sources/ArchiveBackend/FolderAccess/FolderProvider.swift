//
//  FolderProvider.swift
//  
//
//  Created by Julian Kahnert on 16.08.20.
//

import Foundation

public protocol FolderProvider: class, Log {
    typealias FolderChangeHandler = (FolderProvider, [FileChange]) -> Void

    static func canHandle(_ url: URL) -> Bool

    var baseUrl: URL { get }

    init(baseUrl: URL, _ handler: @escaping FolderChangeHandler)

    func save(data: Data, at: URL) throws
    func startDownload(of: URL) throws
    func fetch(url: URL) throws -> Data
    func delete(url: URL) throws
    func rename(from: URL, to: URL) throws
    func getCreationDate(of: URL) throws -> Date?
}
