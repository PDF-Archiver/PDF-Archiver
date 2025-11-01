//
//  Document.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import Foundation

nonisolated public struct Document: Equatable, Hashable, Sendable, Codable, Identifiable {
    /// Type alias for document identifier
    public typealias ID = Int

    public var id: ID
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
    nonisolated public static func createFilename(date: Date, specification: String, tags: Set<String>) -> String {
        // get formatted date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)

        // get description

        // get tags
        var tagStr = ""
        for tag in tags.sorted() {
            tagStr += "\(tag)_"
        }
        tagStr = String(tagStr.dropLast(1))

        // create new file path
        return "\(dateStr)--\(specification)__\(tagStr).pdf".lowercased()
    }

    // swiftlint:disable:next force_unwrapping
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
