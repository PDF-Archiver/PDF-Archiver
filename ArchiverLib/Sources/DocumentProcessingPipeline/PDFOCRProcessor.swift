//
//  PDFOCRProcessor.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 02.03.26.
//

import Foundation
import OSLog
import PDFKit
import Vision

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
private typealias PlatformFont = UIFont
#else
import AppKit
private typealias PlatformColor = NSColor
private typealias PlatformFont = NSFont
#endif

/// Recognized text with its bounding box in normalized coordinates.
struct RecognizedText: Sendable {
    let text: String
    let boundingBox: CGRect
}

/// Adds an invisible text layer to image-only PDFs using Vision framework OCR.
///
/// This processor can be used standalone (e.g. from the `ocr-tool` CLI)
/// or as part of the ``DocumentProcessingPipeline`` via ``OCRProcessingStep``.
public enum PDFOCRProcessor {

    /// Performs OCR on a PDF at the given URL if it lacks a text layer.
    /// Modified pages receive invisible text annotations for searchability.
    /// - Parameter url: The PDF file URL to process.
    /// - Returns: `true` if the file was modified and saved.
    public static func processOCR(url: URL) async -> Bool {
        guard let pdfDocument = PDFDocument(url: url) else { return false }
        if PDFTextExtractor.extractText(from: url) != nil { return false }
        guard let ocrDocument = await performOCR(on: pdfDocument) else { return false }

        do {
            try replaceFile(at: url, with: ocrDocument)
            Logger.ocrStep.info("OCR completed for: \(url.lastPathComponent)")
            return true
        } catch {
            Logger.ocrStep.error("OCR file replacement failed for \(url.lastPathComponent): \(error)")
            return false
        }
    }

    /// Performs OCR on a PDF at the given URL and reports per-page progress.
    /// - Parameters:
    ///   - url: The PDF file URL to process.
    ///   - onPage: Callback with (pageIndex, pageCount, recognizedRegions) per processed page.
    /// - Returns: `true` if the file was modified and saved.
    public static func processOCR(
        url: URL,
        onPage: (Int, Int, Int) -> Void
    ) async -> Bool {
        guard let pdfDocument = PDFDocument(url: url) else { return false }
        if PDFTextExtractor.extractText(from: url) != nil { return false }

        var pagesModified = 0
        let pageCount = pdfDocument.pageCount

        for pageIndex in 0..<pageCount {
            guard !Task.isCancelled else { return false }
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            if let text = page.string,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            let pageBounds = page.bounds(for: .mediaBox)
            guard let cgImage = renderPageToImage(page, bounds: pageBounds) else { continue }

            let observations = await recognizeText(in: cgImage)
            guard !observations.isEmpty else { continue }

            addTextOverlay(to: page, bounds: pageBounds, observations: observations)
            pagesModified += 1
            onPage(pageIndex, pageCount, observations.count)
        }

        guard pagesModified > 0 else { return false }

        do {
            try replaceFile(at: url, with: pdfDocument)
            return true
        } catch {
            Logger.ocrStep.error("OCR file replacement failed for \(url.lastPathComponent): \(error)")
            return false
        }
    }

    // MARK: - Internal

    static func performOCR(on pdf: PDFDocument) async -> PDFDocument? {
        var pagesModified = 0

        for pageIndex in 0..<pdf.pageCount {
            guard !Task.isCancelled else { return nil }
            guard let page = pdf.page(at: pageIndex) else { continue }

            if let text = page.string,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            let pageBounds = page.bounds(for: .mediaBox)
            guard let cgImage = renderPageToImage(page, bounds: pageBounds) else { continue }

            let observations = await recognizeText(in: cgImage)
            guard !observations.isEmpty else { continue }

            addTextOverlay(to: page, bounds: pageBounds, observations: observations)
            pagesModified += 1
        }

        return pagesModified > 0 ? pdf : nil
    }

    static func renderPageToImage(_ page: PDFPage, bounds: CGRect) -> CGImage? {
        let scale: CGFloat = 2.0
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        context.scaleBy(x: scale, y: scale)

        #if canImport(UIKit)
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        #endif

        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    static func recognizeText(in image: CGImage) async -> [RecognizedText] {
        do {
            var request = RecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let observations = try await request.perform(on: image)
            return observations.compactMap { observation -> RecognizedText? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return RecognizedText(text: candidate.string, boundingBox: observation.boundingBox.cgRect)
            }
        } catch {
            Logger.ocrStep.error("Text recognition failed: \(error)")
            return []
        }
    }

    static func addTextOverlay(to page: PDFPage, bounds: CGRect, observations: [RecognizedText]) {
        for observation in observations {
            let rect = CGRect(
                x: observation.boundingBox.origin.x * bounds.width,
                y: observation.boundingBox.origin.y * bounds.height,
                width: observation.boundingBox.width * bounds.width,
                height: observation.boundingBox.height * bounds.height
            )

            let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
            annotation.contents = observation.text
            annotation.font = PlatformFont.systemFont(ofSize: rect.height * 0.8)
            annotation.fontColor = PlatformColor.clear
            annotation.color = PlatformColor.clear
            annotation.isReadOnly = true
            page.addAnnotation(annotation)
        }
    }

    private static func replaceFile(at originalURL: URL, with document: PDFDocument) throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        document.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(originalURL, withItemAt: tempURL)
    }
}
