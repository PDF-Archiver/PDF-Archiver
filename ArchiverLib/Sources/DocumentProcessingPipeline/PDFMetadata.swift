//
//  PDFMetadata.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

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

    /// Returns `true` if the PDF has extractable text on any of its first pages.
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
            return true
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
    public static func markAsProcessed(_ pdf: PDFDocument, marker: String, writeTo url: URL) {
        var attributes = pdf.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.creatorAttribute] = marker
        pdf.documentAttributes = attributes
        pdf.write(to: url)
    }
}
