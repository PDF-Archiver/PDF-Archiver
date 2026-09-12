//
//  CorpusDocument.swift
//  ArchiverLib
//

import ArchiverModels
import Foundation

/// One already-filed archive document reduced to what an evaluation needs: the
/// text the app would send to the model, and the ground truth the user has
/// already committed to in the filename.
public struct CorpusDocument: Codable, Equatable, Sendable {

    /// Original filename, kept so a sample can be traced back to its PDF while
    /// reading the Xcode evaluation report.
    public let filename: String
    public let date: Date
    public let specification: String
    public let tags: [String]
    public let text: String

    public init(filename: String, date: Date, specification: String, tags: [String], text: String) {
        self.filename = filename
        self.date = date
        self.specification = specification
        self.tags = tags
        self.text = text
    }
}

public extension CorpusDocument {
    /// The archive entry this record stands for, as `ContentExtractorStore` sees
    /// it while building the prompt context.
    ///
    /// - Parameter id: Position in the context array. The id never leaves the
    ///   evaluation, so any value unique within the array will do.
    func asArchiveDocument(id: Document.ID) -> Document {
        Document(id: id,
                 url: URL(filePath: filename),
                 date: date,
                 // `Document.create` un-slugifies a filed specification, so the
                 // prompt has to see the spaced wording the app would show.
                 specification: specification.replacing("-", with: " "),
                 tags: Set(tags),
                 isTagged: true,
                 sizeInBytes: Double(text.utf8.count),
                 downloadStatus: 1)
    }

    /// The corpus file format, spelled out once so the builder, the capability
    /// report and the evaluations cannot drift apart on the date strategy.
    static func corpus(from data: Data) throws -> [CorpusDocument] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CorpusDocument].self, from: data)
    }

    static func data(from corpus: [CorpusDocument]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(corpus)
    }
}
