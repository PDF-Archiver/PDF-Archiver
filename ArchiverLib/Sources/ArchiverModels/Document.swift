//
//  Document.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import Foundation

public struct Document: Equatable, Identifiable, Hashable, Sendable, Codable {
    public var id: Int
    public var url: URL
    public var date: Date
    public var specification: String
    public var tags: Set<String>

    public var isTagged: Bool
    public var sizeInBytes: Double

    // 0: remote - 1: local
    public var downloadStatus: Double

    public var filename: String {
        url.lastPathComponent
    }

    public init(id: Int, url: URL, date: Date, specification: String, tags: Set<String>, isTagged: Bool, sizeInBytes: Double, downloadStatus: Double) {
        self.id = id
        self.url = url
        self.date = date
        self.specification = specification
        self.tags = tags
        self.isTagged = isTagged
        self.sizeInBytes = sizeInBytes
        self.downloadStatus = downloadStatus
    }
}

extension Document {
    public static func mock(url: URL = URL(string: "https://example.com")!, date: Date = Date(), specification: String = "", tags: Set<String> = [], isTagged: Bool = true, sizeInBytes: Double = 1000, downloadStatus: Double = 0) -> Self {
        .init(
            id: url.hashValue,
            url: url,
            date: date,
            specification: specification,
            tags: tags,
            isTagged: isTagged,
            sizeInBytes: sizeInBytes,
            downloadStatus: downloadStatus
        )
    }
}
