//
//  Document.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import Foundation
import StructuredQueries

/// One PDF in the archive, as the SQLite read model stores it.
///
/// The file system stays the source of truth: every column is derived from a file's name, folder
/// and resource values, and the whole table can be dropped and rebuilt from the files.
@Table
nonisolated public struct Document: Equatable, Hashable, Sendable, Codable, Identifiable {
    /// Type alias for document identifier
    public typealias ID = Int

    public var id: ID
    /// Logical key of the observed root, never derived from the URL text - the same file appears
    /// as `/private/var/…` and `/var/…`, and the iOS container path changes with app updates.
    public var rootKey: String
    public var url: URL
    public var filename: String
    public var date: Date
    /// `Calendar.current` year of `date`. `date` is stored in UTC, so year buckets must not
    /// derive the year from it.
    public var year: Int
    public var specification: String
    @Column(as: SortedTagsRepresentation.self)
    public var tags: Set<String>

    public var isTagged: Bool
    public var sizeInBytes: Double

    // 0: remote - 1: local
    public var downloadStatus: Double

    public var contentModificationDate: Date?

    public init(id: ID,
                rootKey: String,
                url: URL,
                filename: String? = nil,
                date: Date,
                year: Int? = nil,
                specification: String,
                tags: Set<String>,
                isTagged: Bool,
                sizeInBytes: Double,
                downloadStatus: Double,
                contentModificationDate: Date? = nil) {
        self.id = id
        self.rootKey = rootKey
        self.url = url
        self.filename = filename ?? url.lastPathComponent
        self.date = date
        self.year = year ?? Calendar.current.component(.year, from: date)
        self.specification = specification
        self.tags = tags
        self.isTagged = isTagged
        self.sizeInBytes = sizeInBytes
        self.downloadStatus = downloadStatus
        self.contentModificationDate = contentModificationDate
    }
}

extension Document {
    /// Placeholders used in filenames of documents that were imported but not tagged yet.
    public static let datePlaceholder = "PDFARCHIVER-TEMP-DATE"
    public static let descriptionPlaceholder = "PDF-ARCHIVER-TEMP-DESCRIPTION-"
    public static let tagPlaceholder = "PDFARCHIVERTEMPTAG"

    nonisolated public static func createFilename(date: Date, specification: String, tags: Set<String>) -> String {
        // get formatted date
        let dateStr = DateFormatter.yyyyMMdd.string(from: date)

        // get tags
        let tagStr = tags.sorted().joined(separator: "_")

        // create new file path
        return "\(dateStr)--\(specification)__\(tagStr).pdf".lowercased()
    }

    /// Parse the filename from an URL.
    ///
    /// - Parameter path: Path which should be parsed.
    /// - Returns: Date, specification and tag names which can be parsed from the path.
    @concurrent
    public static func parseFilename(_ filename: String) async -> (date: Date?, specification: String?, tagNames: [String]?) {

        // try to parse the current filename
        var date: Date?
        if let parsed = Self.getFilenameDate(filename) {
            date = parsed
        } else if let parsedDate = await DateParser.parse(filename).first {
            date = parsedDate
        }

        // parse the specification
        var specification: String?

        let components = filename.components(separatedBy: "--")
        if components.count == 2,
           let lastComponents = components.last?.components(separatedBy: "__"),
           lastComponents.count == 2,
           let raw = lastComponents.first,
           !raw.isEmpty {

            // try to parse the real specification from scheme
            specification = raw
        }

        // parse the tags
        var tagNames: [String]?
        let separator = "__"
        if filename.contains(separator),
           let raw = filename.components(separatedBy: separator).last?.dropLast(filename.hasSuffix(".pdf") ? 4 : 0),
           !raw.isEmpty {
            // parse the tags of a document
            tagNames = raw.lowercased()
                .components(separatedBy: "_")
                .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
        }

        if let foundSpecification = specification,
           foundSpecification.lowercased().starts(with: Self.descriptionPlaceholder.lowercased()) {
            specification = nil
        }
        if let foundTagNames = tagNames,
            foundTagNames.contains(where: { $0.lowercased() == Self.tagPlaceholder.lowercased() }) {
            tagNames = nil
        }

        return (date, specification, tagNames)
    }

    nonisolated private static func getFilenameDate(_ filename: String) -> Date? {
        var rawDate: String?

        let dashComponents = filename.components(separatedBy: "--")
        let underscoreComponents = filename.components(separatedBy: "__")
        if dashComponents.count > 1 {
            rawDate = dashComponents.first
        } else if underscoreComponents.count > 1 {
            rawDate = underscoreComponents.first
        }

        guard let rawDate else { return nil }
        return DateFormatter.yyyyMMdd.date(from: rawDate)
    }

    public static func mock(url: URL = URL(string: "https://example.com")!, date: Date = Date(), specification: String = "", tags: Set<String> = [], isTagged: Bool = true, sizeInBytes: Double = 1000, downloadStatus: Double = 0) -> Self {
        .init(
            id: url.absoluteString.stableHashValue,
            rootKey: "mock",
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
