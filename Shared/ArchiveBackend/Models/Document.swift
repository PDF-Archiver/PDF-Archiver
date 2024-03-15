//
//  Document.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 13.11.18.
//

import Foundation
#if os(OSX)
import Quartz.PDFKit
#else
import PDFKit
#endif

private let dateFormatter = DateFormatter.with("yyyy-MM-dd")
extension Document: Searchitem {}

public final class Document: Identifiable, Codable, Log {

    public var id: String {
        path.absoluteString + downloadStatus.description
    }

    public var date: Date?
    public var specification = ""
    public var tags = Set<String>()

    public var downloadStatus: FileChange.DownloadStatus
    public var taggingStatus: TaggingStatus

    public let size: String
    public internal(set) var path: URL
    public internal(set) var filename: String {
        didSet {
            term = filename.lowercased().utf8.map { UInt8($0) }
        }
    }
    public private(set) lazy var term: Term = filename.lowercased().utf8.map { UInt8($0) }
    public var folder: String {
        path.deletingLastPathComponent().lastPathComponent
    }

    public convenience init(from details: FileChange.Details, with taggingStatus: TaggingStatus) {
        self.init(path: details.url,
                  taggingStatus: taggingStatus,
                  downloadStatus: details.downloadStatus,
                  byteSize: details.size)
    }

    public init(path: URL, taggingStatus: TaggingStatus, downloadStatus: FileChange.DownloadStatus, byteSize: Int) {
        self.path = path
        self.filename = (try? path.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? path.lastPathComponent
        self.taggingStatus = taggingStatus
        self.size = ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)
        self.downloadStatus = downloadStatus
    }

    /// Parse the filename from an URL.
    ///
    /// - Parameter path: Path which should be parsed.
    /// - Returns: Date, specification and tag names which can be parsed from the path.
    public static func parseFilename(_ filename: String) -> (date: Date?, specification: String?, tagNames: [String]?) {

        // try to parse the current filename
        var date: Date?
        var rawDate = ""
        if let parsed = Document.getFilenameDate(filename) {
            date = parsed.date
            rawDate = parsed.rawDate
        } else if let parsed = DateParser.parse(filename) {
            date = parsed.date
            rawDate = parsed.rawDate
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

        } else {

            // save a first "raw" specification
            let tempSepcification = filename.lowercased()
                // drop the already parsed date
                .dropFirst(rawDate.count)
                // drop the extension and the last .
                .dropLast(filename.hasSuffix(".pdf") ? 4 : 0)
                // exclude tags, if they exist
                .components(separatedBy: "__")[0]
                // clean up all "_" - they are for tag use only!
                .replacingOccurrences(of: "_", with: "-")
                // remove a pre or suffix from the string
                .trimmingCharacters(in: ["-", " "])

            // save the raw specification, if it is not empty
            if !tempSepcification.isEmpty {
                specification = tempSepcification
            }
        }

        // parse the tags
        var tagNames: [String]?
        let separator = "__"
        if filename.contains(separator),
           let raw = filename.components(separatedBy: separator).last?.dropLast(filename.hasSuffix(".pdf") ? 4 : 0),
           !raw.isEmpty {
            // parse the tags of a document
            tagNames = raw.components(separatedBy: "_")
        }

        return (date, specification, tagNames)
    }

    private static func getFilenameDate(_ filename: String) -> (date: Date, rawDate: String)? {
        var rawDate: String?
        if let components = filename.components(separatedBy: "--") as [String]?, components.count > 1 {
            rawDate = components.first
        } else if let components = filename.components(separatedBy: "__") as [String]?, components.count > 1 {
            rawDate = components.first
        }

        guard let rawDate,
              let date = DateFormatter.yyyyMMdd.date(from: rawDate) else { return nil }
        return (date, rawDate)
    }

    public static func createFilename(date: Date, specification: String, tags: Set<String>) -> String {
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
        return "\(dateStr)--\(specification)__\(tagStr).pdf"
    }

    /// This function updates the properties of the document.
    ///
    /// Since it might run some time, this should not be run on the main thread.
    func updateProperties(with downloadStatus: FileChange.DownloadStatus) {
        filename = (try? path.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? self.path.lastPathComponent

        // parse the current filename and add finder file tags
        let parsedFilename = Document.parseFilename(self.filename)
        let placeholderTag = Constants.documentTagPlaceholder.lowercased()
        let tags = Set(parsedFilename.tagNames ?? [])
            .union(path.getFileTags())
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.lowercased() != placeholderTag }

        self.downloadStatus = downloadStatus

        // set the date
        self.date = parsedFilename.date

        // set the specification
        let specification = parsedFilename.specification ?? ""
        if specification.lowercased().contains(Constants.documentDescriptionPlaceholder.lowercased()) {
            self.specification = ""
        } else {
            self.specification = specification
        }

        self.tags = tags
    }

    // MARK: - Codable Implementation

    private enum CodingKeys: CodingKey {
        case date, specification, tags, size, downloadStatus, taggingStatus, path, filename
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try? container.decode(Date.self, forKey: .date)
        specification = try container.decode(String.self, forKey: .specification)
        tags = try container.decode(Set<String>.self, forKey: .tags)
        size = try container.decode(String.self, forKey: .size)
        downloadStatus = try container.decode(FileChange.DownloadStatus.self, forKey: .downloadStatus)
        taggingStatus = try container.decode(Document.TaggingStatus.self, forKey: .taggingStatus)
        path = try container.decode(URL.self, forKey: .path)
        filename = try container.decode(String.self, forKey: .filename)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(specification, forKey: .specification)
        try container.encode(tags, forKey: .tags)
        try container.encode(size, forKey: .size)
        try container.encode(downloadStatus, forKey: .downloadStatus)
        try container.encode(taggingStatus, forKey: .taggingStatus)
        try container.encode(path, forKey: .path)
        try container.encode(filename, forKey: .filename)
    }
}

#if DEBUG
// swiftlint:disable force_unwrapping
extension Document {
    public static func create(taggingStatus: TaggingStatus = .untagged) -> Document {
//        Document(path: URL(string: "~/test.pdf")!,
//                 size: Int.random(in: 0..<512000),
//                 downloadStatus: .local)

        let name = UUID().uuidString.prefix(5)
        return Document(path: URL(string: "~/test-\(name).pdf")!, taggingStatus: taggingStatus, downloadStatus: .downloading(percent: 0.33), byteSize: 512)
    }

    public static func createWithInfo(taggingStatus: TaggingStatus, tags: Set<String>, folderName: String) -> Document {
        let name = UUID().uuidString.prefix(5)
        let url = URL(string: "~/\(folderName)/2020-12-27--\(name)__\(tags.sorted().joined(separator: "_")).pdf")!
        let document = Document(path: url, taggingStatus: taggingStatus, downloadStatus: .downloading(percent: 0.33), byteSize: 512)
        document.tags = tags

        return document
    }
}
#endif
