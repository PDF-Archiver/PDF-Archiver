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

extension Document: Searchitem {}

public final class Document: ObservableObject, Identifiable, Codable, Log {
    public var id: URL {
        path
    }

    @Published public var date: Date?
    @Published public var specification = ""
    @Published public var tags = Set<String>()

    @Published public var downloadStatus: FileChange.DownloadStatus
    @Published public var taggingStatus: TaggingStatus

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

        if let raw = filename.capturedGroups(withRegex: "--([\\w\\d-]+)__") {

            // try to parse the real specification from scheme
            specification = raw[0]

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

    private static func getFilenameDate(_ raw: String) -> (date: Date, rawDate: String)? {
        if let groups = raw.capturedGroups(withRegex: "([\\d-]+)--") {
            let rawDate = groups[0]

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            if let date = dateFormatter.date(from: rawDate) {
                return (date, rawDate)
            }
        }
        return nil
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

        // create new filepath
        return "\(dateStr)--\(specification)__\(tagStr).pdf"
    }

    func updateProperties(with downloadStatus: FileChange.DownloadStatus, contentParsingOptions: ParsingOptions) {
        if Thread.isMainThread {
            log.errorAndAssert("updateProperties() must not be called from the main thread.")
        }
        filename = (try? path.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? self.path.lastPathComponent

        // parse the current filename and add finder file tags
        let parsedFilename = Document.parseFilename(self.filename)
        let tags = Set(parsedFilename.tagNames ?? []).union(path.fileTags)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0 != Constants.documentTagPlaceholder }

        DispatchQueue.main.sync {
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

        guard downloadStatus == .local,
              !contentParsingOptions.isEmpty else { return }
        self.parseContent(contentParsingOptions)
    }

    /// Get the new foldername and filename after applying the PDF Archiver naming scheme.
    ///
    /// ATTENTION: The specification will not be slugified in this step! Keep in mind to do this before/after this method call.
    ///
    /// - Returns: Returns the new foldername and filename after renaming.
    /// - Throws: This method throws an error, if the document contains no tags or specification.
    public func getRenamingPath() throws -> (foldername: String, filename: String) {

        // create a filename and rename the document
        guard let date = date else {
            throw FolderProviderError.date
        }
        guard !tags.isEmpty else {
            throw FolderProviderError.tags
        }
        guard !specification.isEmpty else {
            throw FolderProviderError.description
        }

        let filename = Document.createFilename(date: date, specification: specification, tags: tags)
        let foldername = String(filename.prefix(4))

        return (foldername, filename)
    }

    /// Parse the OCR content of the pdf document try to fetch a date and some tags.
    /// This overrides the current date and appends the new tags.
    ///
    /// ATTENTION: This method needs security access!
    ///
    /// - Parameter tagManager: TagManager that will be used when adding new tags.
    private func parseContent(_ options: ParsingOptions) {
        if Thread.isMainThread {
            log.errorAndAssert("parseContent() must not be called from the main thread.")
        }

        // skip the calculations if the OptionSet is empty
        guard !options.isEmpty else { return }

        // get the pdf content of first 3 pages
        guard let pdfDocument = PDFDocument(url: path) else { return }
        var text = ""
        for index in 0 ..< min(pdfDocument.pageCount, 3) {
            guard let page = pdfDocument.page(at: index),
                let pageContent = page.string else { return }

            text += pageContent
        }

        // verify that we got some pdf content
        guard !text.isEmpty else { return }

        // parse the date
        if options.contains(.date),
            let parsed = DateParser.parse(text) {
            DispatchQueue.main.sync {
                self.date = parsed.date
            }
        }

        // parse the tags
        if options.contains(.tags) {

            // get new tags
            let newTags = TagParser.parse(text)
            DispatchQueue.main.sync {
                self.tags.formUnion(newTags)
            }
        }
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
    public static func create() -> Document {
//        Document(path: URL(string: "~/test.pdf")!,
//                 size: Int.random(in: 0..<512000),
//                 downloadStatus: .local)

        Document(path: URL(string: "~/test.pdf")!, taggingStatus: .untagged, downloadStatus: .downloading(percent: 0.33), byteSize: 512)
    }
}
#endif
