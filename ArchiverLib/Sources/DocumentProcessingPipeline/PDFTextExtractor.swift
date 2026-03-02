//
//  PDFTextExtractor.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 01.03.26.
//

import Foundation
import PDFKit

/// Built-in PDF text extraction utility
public enum PDFTextExtractor {
    /// Extract text from the first pages of a PDF
    /// - Parameters:
    ///   - url: PDF file URL
    ///   - maxPages: Maximum number of pages to extract (default: 3)
    /// - Returns: Extracted text, or nil if no text found
    public static func extractText(from url: URL, maxPages: Int = 3) -> String? {
        guard let pdf = PDFDocument(url: url) else { return nil }
        var text = ""
        for pageIndex in 0..<min(pdf.pageCount, maxPages) {
            guard let page = pdf.page(at: pageIndex),
                  let content = page.string else { continue }
            text += content
        }
        return text.isEmpty ? nil : text
    }
}
