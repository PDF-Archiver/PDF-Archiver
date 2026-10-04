//
//  PDFMetadata.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import ArchiverModels
import Foundation
import Logging
import PDFKit

/// Helpers for reading and writing the metadata flag used to track which
/// documents were already processed.
///
/// # Deduplication strategy
///
/// Documents placed in the untagged folder must not be re-OCR'd on every
/// app launch. The configured marker string plus the engine version is
/// written into the `Creator` attribute after every OCR attempt — including
/// failed ones — so the same file is never retried in a loop by the same
/// engine. Raising the engine version grants every stamped file one more
/// attempt, which is how an improved engine reaches an existing archive.
///
/// `Creator` is used instead of `Producer` because `PDFDocument.write(to:)`
/// unconditionally overwrites `Producer` with the Quartz PDFContext value,
/// which makes it unusable as a persistent flag.
public enum PDFMetadata {

    /// Returns `true` if the PDF has *usable* extractable text on any of its
    /// first pages.
    ///
    /// A layer that extracts as mojibake (see ``TextReadability``) is worthless
    /// for search and AI suggestions, so it does not count and the document
    /// gets OCR'd again.
    ///
    /// - Parameters:
    ///   - pdf: The PDF to inspect.
    ///   - maxPages: Number of pages to probe (default: 3). Keeps the check
    ///     cheap for large documents — if the first few pages have no text,
    ///     the document is treated as image-only.
    public static func hasTextLayer(_ pdf: PDFDocument, maxPages: Int = 3) -> Bool {
        (0..<min(pdf.pageCount, maxPages)).contains { index in
            guard let page = pdf.page(at: index),
                  let text = page.string,
                  !text.isEmpty else { return false }
            return TextReadability.isReadable(text)
        }
    }

    /// Returns the OCR engine version that stamped the PDF, or `nil` if it was
    /// never processed by this app.
    ///
    /// - `"PDF Archiver"` (no suffix) is a file stamped before versioning and
    ///   counts as version `1`.
    /// - An unparseable suffix also counts as `1`, so a malformed marker is
    ///   retried instead of being trusted forever.
    public static func processedEngineVersion(_ pdf: PDFDocument, markerPrefix: String) -> Int? {
        guard let creator = pdf.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String,
              creator.hasPrefix(markerPrefix) else { return nil }

        let suffix = creator.dropFirst(markerPrefix.count).trimmingCharacters(in: .whitespaces)
        guard suffix.hasPrefix("v"), let version = Int(suffix.dropFirst()) else { return 1 }
        return version
    }

    /// The `Creator` value written for `marker` at `version`.
    public static func markerValue(marker: String, version: Int) -> String {
        "\(marker) v\(version)"
    }

    /// Sets the `Creator` metadata to `"<marker> v<version>"` in memory.
    ///
    /// Shared by both OCR entry points so a scanned document is born at the
    /// current engine version instead of being re-OCR'd by the same engine.
    public static func stamp(_ pdf: PDFDocument, marker: String, version: Int) {
        var attributes = pdf.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.creatorAttribute] = markerValue(marker: marker, version: version)
        pdf.documentAttributes = attributes
    }

    /// Sets the `Creator` metadata to `"<marker> v<version>"` and writes the
    /// PDF to disk.
    ///
    /// Called after every OCR attempt (including failures) so the same file is
    /// never retried in a loop by the same engine version. Raising the engine
    /// version grants the file one further attempt.
    ///
    /// - Returns: Whether the file was written successfully.
    @discardableResult
    public static func markAsProcessed(_ pdf: PDFDocument, marker: String, version: Int, writeTo url: URL) -> Bool {
        stamp(pdf, marker: marker, version: version)
        do {
            try pdf.writeAtomically(to: url)
            return true
        } catch {
            Logger.ocrProcessing.error("Failed to write PDF", metadata: [
                "document": "\(LogRedact.token(url))",
                "error": "\(LogRedact.describe(error))"
            ])
            return false
        }
    }
}

extension PDFDocument {
    enum WriteError: Error, LogSafeError {
        case noDataRepresentation

        var logDescription: String { "\(self)" }
    }

    /// `write(to:)` streams straight into the target file, so a crash mid-write
    /// leaves the user's document truncated; `.atomic` renames a finished copy.
    func writeAtomically(to url: URL) throws {
        guard let data = dataRepresentation() else { throw WriteError.noDataRepresentation }
        try data.write(to: url, options: .atomic)
    }
}
