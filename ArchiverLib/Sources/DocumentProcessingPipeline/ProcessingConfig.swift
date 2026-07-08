//
//  ProcessingConfig.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import ArchiverModels
import Foundation

/// Everything the pipeline needs to know about the app it runs in.
///
/// The config is passed per request so callers can resolve live values
/// (e.g. a user-changeable PDF quality or storage location) at enqueue time.
/// The pipeline itself never reads settings.
public struct ProcessingConfig: Sendable {
    /// Folder finished documents are written to (in the app: the untagged folder).
    public var destinationFolder: URL

    /// JPEG compression used for scanned page images and re-rendered OCR pages.
    public var pdfQuality: PDFQuality

    /// Marker written to the PDF `Creator` attribute after processing.
    ///
    /// Also used as prefix when checking whether a document was processed
    /// before. `Creator` is used instead of `Producer` because
    /// `PDFDocument.write(to:)` unconditionally overwrites `Producer` with the
    /// Quartz PDFContext value, which makes it unusable as a persistent flag.
    public var processedMarker: String

    public init(destinationFolder: URL, pdfQuality: PDFQuality, processedMarker: String) {
        self.destinationFolder = destinationFolder
        self.pdfQuality = pdfQuality
        self.processedMarker = processedMarker
    }
}

/// Enables the AI pass of ``DocumentProcessor/processUntaggedDocuments(in:config:ai:)``.
///
/// The caller decides whether AI suggestions should be pre-computed (e.g. by
/// checking the Apple Intelligence and cache settings) and passes `nil` to
/// skip the pass entirely.
public struct AIContext: Sendable {
    /// Optional custom instructions forwarded to the content extraction prompt.
    public var customPrompt: String?

    public init(customPrompt: String? = nil) {
        self.customPrompt = customPrompt
    }
}
