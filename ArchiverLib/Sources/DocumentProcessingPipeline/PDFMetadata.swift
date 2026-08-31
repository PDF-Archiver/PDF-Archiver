//
//  PDFMetadata.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import ArchiverModels
import Foundation
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
        var attributes = pdf.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.creatorAttribute] = "\(marker) v\(version)"
        pdf.documentAttributes = attributes
        return pdf.write(to: url)
    }
}
