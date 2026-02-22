//
//  OCRProcessingStep.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import ArchiverModels
import Foundation
import OSLog
import PDFKit
import Shared
import Sharing
import Vision

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#else
import AppKit
private typealias PlatformColor = NSColor
#endif

/// Adds an invisible text layer to image-only PDFs using Vision framework OCR
/// Sendable representation of a recognized text observation
private struct RecognizedText: Sendable {
    let text: String
    let boundingBox: CGRect
}

public struct OCRProcessingStep: DocumentProcessingStep, Sendable {
    public let name = "OCR"

    @SharedReader(.ocrEnabled) private var ocrEnabled: Bool

    public var isEnabled: Bool { ocrEnabled }

    public init() {}

    public func process(context: DocumentProcessingContext) async -> DocumentProcessingStepResult {
        let untaggedDocuments = context.documents.filter { !$0.isTagged }
        var processedCount = 0

        for document in untaggedDocuments {
            guard !Task.isCancelled else { break }

            // Only process fully downloaded documents
            guard document.downloadStatus == 1 else { continue }

            let url = document.url
            guard let pdfDocument = PDFDocument(url: url) else { continue }

            // Skip if pages already have text
            if pdfHasText(pdfDocument) { continue }

            // Perform OCR and create new PDF with text overlay
            guard let ocrDocument = await performOCR(on: pdfDocument) else { continue }

            // Replace original file atomically
            do {
                try replaceFile(at: url, with: ocrDocument)
                processedCount += 1
                Logger.processingPipeline.info("OCR completed for: \(url.lastPathComponent)")
            } catch {
                Logger.processingPipeline.error("OCR file replacement failed for \(url.lastPathComponent): \(error)")
            }
        }

        return DocumentProcessingStepResult(stepName: name, documentsProcessed: processedCount)
    }

    // MARK: - Private helpers

    func pdfHasText(_ pdf: PDFDocument) -> Bool {
        for pageIndex in 0..<min(pdf.pageCount, 3) {
            if let page = pdf.page(at: pageIndex),
               let text = page.string,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        return false
    }

    private func performOCR(on pdf: PDFDocument) async -> PDFDocument? {
        let newDocument = PDFDocument()

        for pageIndex in 0..<pdf.pageCount {
            guard !Task.isCancelled else { return nil }
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)

            // Render page to CGImage for OCR
            guard let cgImage = renderPageToImage(page, bounds: pageBounds) else {
                newDocument.insert(page, at: pageIndex)
                continue
            }

            // Run text recognition
            let observations = await recognizeText(in: cgImage)

            if observations.isEmpty {
                newDocument.insert(page, at: pageIndex)
                continue
            }

            // Create new page with invisible text overlay
            if let newPage = createPageWithTextOverlay(
                originalPage: page,
                bounds: pageBounds,
                observations: observations
            ) {
                newDocument.insert(newPage, at: pageIndex)
            } else {
                newDocument.insert(page, at: pageIndex)
            }
        }

        return newDocument.pageCount > 0 ? newDocument : nil
    }

    private func renderPageToImage(_ page: PDFPage, bounds: CGRect) -> CGImage? {
        // Render at 2x for better OCR accuracy
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

        // PDFPage.draw expects a flipped coordinate system on some platforms
        #if canImport(UIKit)
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        #endif

        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    private func recognizeText(in image: CGImage) async -> [RecognizedText] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    Logger.processingPipeline.error("VNRecognizeTextRequest failed: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                // Convert to sendable representation
                let results = observations.compactMap { observation -> RecognizedText? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedText(text: candidate.string, boundingBox: observation.boundingBox)
                }
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                Logger.processingPipeline.error("VNImageRequestHandler failed: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    private func createPageWithTextOverlay(
        originalPage: PDFPage,
        bounds: CGRect,
        observations: [RecognizedText]
    ) -> PDFPage? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { return nil }

        var mediaBox = bounds
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        context.beginPDFPage(nil)

        // Draw original page content
        originalPage.draw(with: .mediaBox, to: context)

        // Draw invisible text at recognized positions
        for observation in observations {
            // Convert from normalized Vision coordinates to PDF coordinates
            let rect = CGRect(
                x: observation.boundingBox.origin.x * bounds.width,
                y: observation.boundingBox.origin.y * bounds.height,
                width: observation.boundingBox.width * bounds.width,
                height: observation.boundingBox.height * bounds.height
            )

            // Draw invisible text for searchability
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: PlatformColor.clear,
                .font: findFittingFont(for: observation.text, in: rect.size)
            ]
            let attributedString = NSAttributedString(string: observation.text, attributes: attributes)

            context.saveGState()
            context.textMatrix = .identity
            attributedString.draw(in: rect)
            context.restoreGState()
        }

        context.endPDFPage()
        context.closePDF()

        guard let newDocument = PDFDocument(data: data as Data),
              let newPage = newDocument.page(at: 0) else { return nil }
        return newPage
    }

    private func findFittingFont(for text: String, in size: CGSize) -> Any {
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: size.height * 0.8)
        #else
        let font = NSFont.systemFont(ofSize: size.height * 0.8)
        #endif
        return font
    }

    private func replaceFile(at originalURL: URL, with document: PDFDocument) throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        document.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(originalURL, withItemAt: tempURL)
    }

    // MARK: - Manual OCR

    /// Run OCR on a single document regardless of the `ocrEnabled` setting or tagged status.
    /// Returns `true` if the file was modified.
    public func performOCROnDocument(_ document: Document) async -> Bool {
        guard document.downloadStatus == 1 else { return false }
        let url = document.url
        guard let pdfDocument = PDFDocument(url: url) else { return false }
        if pdfHasText(pdfDocument) { return false }
        guard let ocrDocument = await performOCR(on: pdfDocument) else { return false }
        do {
            try replaceFile(at: url, with: ocrDocument)
            Logger.processingPipeline.info("Manual OCR completed for: \(url.lastPathComponent)")
            return true
        } catch {
            Logger.processingPipeline.error("Manual OCR file replacement failed for \(url.lastPathComponent): \(error)")
            return false
        }
    }
}
