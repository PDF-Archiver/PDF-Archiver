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
/// app launch. The configured marker string is written into the `Creator`
/// attribute after every OCR attempt — including failed ones — so the same
/// file is never retried in a loop.
///
/// `Creator` is used instead of `Producer` because `PDFDocument.write(to:)`
/// unconditionally overwrites `Producer` with the Quartz PDFContext value,
/// which makes it unusable as a persistent flag.
public enum PDFMetadata {

    /// Returns `true` if the PDF has *usable* extractable text on any of its
    /// first pages.
    ///
    /// A text layer whose `ToUnicode` CMap does not match the embedded font
    /// subset extracts as mojibake (see ``TextReadability``). It is worthless
    /// for search and for the AI suggestions, so it does not count as a text
    /// layer and the document gets OCR'd again.
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

    /// Returns `true` if the PDF's `Creator` metadata starts with `markerPrefix`.
    public static func isMarked(_ pdf: PDFDocument, markerPrefix: String) -> Bool {
        guard let creator = pdf.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String else {
            return false
        }
        return creator.hasPrefix(markerPrefix)
    }

    /// Sets the `Creator` metadata to `marker` and writes the PDF to disk.
    ///
    /// Called after every OCR attempt (including failures) so the same file
    /// is never retried in a loop.
    ///
    /// - Returns: Whether the file was written successfully.
    @discardableResult
    public static func markAsProcessed(_ pdf: PDFDocument, marker: String, writeTo url: URL) -> Bool {
        var attributes = pdf.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.creatorAttribute] = marker
        pdf.documentAttributes = attributes
        return pdf.write(to: url)
    }
}
