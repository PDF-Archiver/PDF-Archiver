//
//  FolderProvider.swift
//  
//
//  Created by Julian Kahnert on 16.08.20.
//

import Foundation

protocol FolderProvider: AnyObject, Log {
    typealias FolderChangeHandler = (any FolderProvider, [FileChange]) -> Void

    static func canHandle(_ url: URL) -> Bool

    var baseUrl: URL { get }
    var isFirstLoading: Bool { get }

    init(baseUrl: URL, _ handler: @escaping FolderChangeHandler) throws

    func save(data: Data, at: URL) throws
    func startDownload(of: URL) throws
    func fetch(url: URL) throws -> Data
    func delete(url: URL) throws
    func rename(from: URL, to: URL) throws
}
