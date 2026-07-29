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

    public init(id: ID, url: URL, date: Date, specification: String, tags: Set<String>, isTagged: Bool, sizeInBytes: Double, downloadStatus: Double) {
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
