//
//  FolderProvider.swift
//  
//
//  Created by Julian Kahnert on 16.08.20.
//

import ArchiverModels
import Foundation
import Shared

@globalActor actor FolderProviderActor: GlobalActor {
    static let shared = FolderProviderActor()
}

struct DocumentInformation: Equatable, Comparable {
    static func < (lhs: DocumentInformation, rhs: DocumentInformation) -> Bool {
        lhs.url.path < rhs.url.path
    }

    let url: URL
    let downloadStatus: Double
    let sizeInBytes: Double
}

@FolderProviderActor
protocol FolderProvider: AnyObject, Log, Sendable {

    static func canHandle(_ url: URL) -> Bool

    // this is a constant, not sure how to declare it in the protocol
    var baseUrl: URL { get }
    var currentDocumentsStream: AsyncStream<[DocumentInformation]> { get }

    init(baseUrl: URL) throws

    func save(data: Data, at: URL) throws
    func startDownload(of: URL) throws
    func fetch(url: URL) throws -> Data
    func delete(url: URL) throws
    func rename(from: URL, to: URL) throws
}
