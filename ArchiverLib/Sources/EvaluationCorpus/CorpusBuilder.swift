//
//  CorpusBuilder.swift
//  ArchiverLib
//

import ArchiverModels
import Foundation
import PDFKit

/// Turns a folder of already-filed PDFs into an evaluation corpus.
///
/// Kept free of the Evaluations framework so the corpus can be built on any Mac,
/// including one that cannot run the evaluations themselves.
public enum CorpusBuilder {

    /// Pages read per document. Matches `TextAnalyserDependency.getTextFrom`, so
    /// the evaluation feeds the model exactly what the tagging form would.
    static let pageLimit = 3

    public enum SkipReason: String, Codable, Sendable {
        /// The filename carries no complete `date--description__tags` triple, so
        /// there is no ground truth to score against.
        case noGroundTruth
        case noTextLayer
        /// Mojibake from a broken text layer - the app drops these too.
        case unreadableText
    }

    public struct Skipped: Equatable, Sendable {
        public let filename: String
        public let reason: SkipReason
    }

    public struct Outcome: Sendable {
        public let documents: [CorpusDocument]
        public let skipped: [Skipped]
    }

    public static func build(fromFolderAt folder: URL) async throws -> Outcome {
        var documents: [CorpusDocument] = []
        var skipped: [Skipped] = []

        for url in try pdfURLs(in: folder) {
            let filename = url.lastPathComponent

            guard let truth = await groundTruth(fromFilename: filename) else {
                skipped.append(Skipped(filename: filename, reason: .noGroundTruth))
                continue
            }
            guard let text = extractText(from: url) else {
                skipped.append(Skipped(filename: filename, reason: .noTextLayer))
                continue
            }
            guard TextReadability.isReadable(text) else {
                skipped.append(Skipped(filename: filename, reason: .unreadableText))
                continue
            }

            documents.append(CorpusDocument(filename: filename,
                                            date: truth.date,
                                            specification: truth.specification,
                                            tags: truth.tags,
                                            text: text))
        }

        return Outcome(documents: documents, skipped: skipped)
    }

    /// Ground truth from the archive naming convention, via the same parser the
    /// app uses. A document only qualifies once date, description and at least
    /// one tag are all present - anything else has nothing to score against.
    static func groundTruth(fromFilename filename: String) async -> (date: Date, specification: String, tags: [String])? {
        let parsed = await Document.parseFilename(filename)
        guard let date = parsed.date,
              let specification = parsed.specification,
              let tags = parsed.tagNames?.filter({ !$0.isEmpty }),
              !specification.isEmpty,
              !tags.isEmpty else { return nil }

        return (date, specification.lowercased(), tags)
    }

    static func extractText(from url: URL) -> String? {
        guard let pdf = PDFDocument(url: url) else { return nil }

        var text = ""
        for index in 0..<min(pdf.pageCount, pageLimit) {
            text += pdf.page(at: index)?.string ?? ""
        }
        return text.isEmpty ? nil : text
    }

    private static func pdfURLs(in folder: URL) throws -> [URL] {
        try FileManager.default
            .subpathsOfDirectory(atPath: folder.path(percentEncoded: false))
            .filter { $0.lowercased().hasSuffix(".pdf") }
            .sorted()
            .map { folder.appending(path: $0) }
    }
}
