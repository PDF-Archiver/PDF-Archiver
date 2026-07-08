//
//  PDFOCREngine.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import ArchiverModels
import Foundation
import OSLog
import PDFKit
import Vision

#if canImport(UIKit)
import UIKit
private typealias Font = UIFont
private typealias Color = UIColor
private typealias DrawingOptions = NSStringDrawingOptions
#else
import AppKit
private typealias Font = NSFont
private typealias Color = NSColor
private typealias DrawingOptions = NSString.DrawingOptions
#endif

// Pre-computed text entries cross an `await` boundary before rendering, so the
// NSAttributedString values need a Sendable conformance. NSAttributedString is
// immutable; declared once in this target.
extension NSAttributedString: @unchecked @retroactive Sendable {}

/// Vision OCR plus PDF page rendering with an invisible text layer.
///
/// One shared core (`recognizeText` + `renderPage`) drives both entry points:
/// - ``createSearchablePDF(fromImagesAt:marker:)`` — the scan path: staged
///   page images become a brand-new searchable PDF.
/// - ``addTextLayer(to:quality:maxPages:)`` — the sweep path: image-only pages
///   of an existing PDF are replaced in place by pages that additionally carry
///   the recognized text.
///
/// Attributed strings are always pre-computed on the main actor *before* the
/// PDF context is created because `NSGraphicsContext.current` is thread-local
/// and would be corrupted across an `await` suspension point.
enum PDFOCREngine {

    private static let confidenceThreshold = Float(0)

    struct TextObservationResult: Sendable {
        let rect: CGRect
        let text: String

        @MainActor
        func getAttributedText() -> NSAttributedString {
            NSAttributedString.createCleared(from: text, with: rect.size)
        }
    }

    // MARK: - Scan driver

    /// Build a searchable PDF from page images on disk (one image per page).
    ///
    /// - Parameters:
    ///   - urls: JPEG page images, in page order.
    ///   - marker: Written to the PDF `Creator` attribute.
    static func createSearchablePDF(fromImagesAt urls: [URL], marker: String) async throws -> PDFDocument {
        let document = PDFDocument()

        for url in urls {
            try Task.checkCancellation()

            guard let image = PlatformImage(contentsOf: url) else {
                Logger.ocrProcessing.error("Could not load page image \(url.lastPathComponent, privacy: .public)")
                continue
            }

            let results = try recognizeText(in: image)
            let textEntries = await makeTextEntries(from: results)
            let bounds = CGRect(origin: .zero, size: image.size)

            guard let page = renderPage(image: image, bounds: bounds, texts: textEntries) else {
                Logger.ocrProcessing.error("Could not render PDF page - skipping page")
                continue
            }
            document.insert(page, at: document.pageCount)
        }

        var attributes = document.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.creatorAttribute] = marker
        document.documentAttributes = attributes
        return document
    }

    // MARK: - In-place driver

    /// Add an invisible OCR text layer to each image-only page of `pdf`.
    ///
    /// Each page is rendered to an image, run through Vision, and replaced
    /// by a new page that draws the page image followed by invisible text in
    /// the recognized positions. The page image is re-encoded as JPEG at
    /// `quality` so the rewritten pages stay compact.
    static func addTextLayer(to pdf: PDFDocument, quality: PDFQuality, maxPages: Int = 10) async throws {
        for pageIndex in 0..<min(pdf.pageCount, maxPages) {
            // Cooperative cancellation: a CancellationError here propagates
            // to the caller, which must NOT write the partially-modified pdf.
            try Task.checkCancellation()

            guard let page = pdf.page(at: pageIndex) else { continue }
            let bounds = page.bounds(for: .mediaBox)

            // 2x resolution for OCR quality.
            let ocrImageSize = CGSize(width: bounds.width * 2, height: bounds.height * 2)
            let ocrImage = page.thumbnail(of: ocrImageSize, for: .mediaBox)

            let ocrResults = try recognizeText(in: ocrImage)
            guard !ocrResults.isEmpty else { continue }

            // Scale OCR coordinates back from the 2x image to page coordinates.
            let scaleX = bounds.width / ocrImageSize.width
            let scaleY = bounds.height / ocrImageSize.height
            let scaledResults = ocrResults.map { result in
                TextObservationResult(
                    rect: CGRect(x: result.rect.origin.x * scaleX,
                                 y: result.rect.origin.y * scaleY,
                                 width: result.rect.width * scaleX,
                                 height: result.rect.height * scaleY),
                    text: result.text)
            }
            let textEntries = await makeTextEntries(from: scaledResults)

            // Original page rendered at 1:1 so drawing coordinates match the
            // PDF context's media box. Re-encode as JPEG so the new page does
            // not blow up the file size with a losslessly stored bitmap.
            let pageImage = page.thumbnail(of: bounds.size, for: .mediaBox)
            let drawImage: PlatformImage
            if let jpegData = pageImage.jpg(quality: CGFloat(quality.rawValue)),
               let jpegImage = PlatformImage(data: jpegData) {
                drawImage = jpegImage
            } else {
                drawImage = pageImage
            }

            guard let newPage = renderPage(image: drawImage, bounds: bounds, texts: textEntries) else { continue }
            pdf.removePage(at: pageIndex)
            pdf.insert(newPage, at: pageIndex)
        }
    }

    // MARK: - Shared core

    /// Run Vision OCR on a single image and return detected text with positions.
    /// Coordinates are in the image's coordinate system (origin top-left, y-down).
    static func recognizeText(in image: PlatformImage) throws -> [TextObservationResult] {
        guard let cgImage = image.cgImage else { return [] }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Detect text rectangles.
        var textRectObservations = [VNTextObservation]()
        let textBoxRequest = VNDetectTextRectanglesRequest { request, error in
            if let error {
                Logger.ocrProcessing.error("Text detection failed: \(error)")
                return
            }
            for observation in (request.results as? [VNTextObservation] ?? []) where observation.confidence > confidenceThreshold {
                textRectObservations.append(observation)
            }
        }
        try requestHandler.perform([textBoxRequest])

        // Recognize text in each detected region.
        var results = [TextObservationResult]()
        for observation in textRectObservations {
            let textBox = transform(observation: observation, in: image.size)
            guard let croppedImage = cgImage.cropping(to: textBox) else { continue }

            let recognizeRequest = VNRecognizeTextRequest { request, error in
                if let error {
                    Logger.ocrProcessing.error("Text recognition failed: \(error)")
                    return
                }
                guard let textResults = request.results as? [VNRecognizedTextObservation],
                      !textResults.isEmpty else { return }
                let texts = textResults.compactMap { $0.topCandidates(1).first?.string }
                    .filter { !$0.isEmpty }
                if !texts.isEmpty {
                    results.append(TextObservationResult(rect: textBox, text: texts.joined(separator: " ")))
                }
            }
            recognizeRequest.recognitionLevel = .accurate
            recognizeRequest.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: croppedImage, options: [:]).perform([recognizeRequest])
        }

        return results
    }

    /// Pre-compute the invisible attributed strings on the main actor, before
    /// any PDF context exists.
    private static func makeTextEntries(from results: [TextObservationResult]) async -> [(rect: CGRect, text: NSAttributedString)] {
        var entries: [(rect: CGRect, text: NSAttributedString)] = []
        for result in results {
            let attributed = await result.getAttributedText()

            // Skip empty observations - they would produce a NaN font expansion.
            guard !result.text.isEmpty else { continue }
            entries.append((rect: result.rect, text: attributed))
        }
        return entries
    }

    /// Draw `image` plus invisible `texts` into a fresh single-page PDF and
    /// return that page. Contains no `await` — `NSGraphicsContext.current`
    /// stays valid for the whole drawing pass.
    private static func renderPage(image: PlatformImage, bounds: CGRect, texts: [(rect: CGRect, text: NSAttributedString)]) -> PDFPage? {
        var mediaBox = bounds
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        #if os(macOS)
        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        #else
        UIGraphicsPushContext(context)
        #endif

        var info = [String: Any]()
        info[kCGPDFContextMediaBox as String] = bounds
        context.beginPDFPage(info as CFDictionary)
        context.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height))

        image.draw(in: bounds)
        for entry in texts {
            entry.text.draw(in: entry.rect)
        }

        context.endPDFPage()
        context.closePDF()

        #if os(macOS)
        NSGraphicsContext.current = previousContext
        #else
        UIGraphicsPopContext()
        #endif

        guard let document = PDFDocument(data: data as Data),
              let page = document.page(at: 0) else { return nil }
        return page
    }

    private static func transform(observation: VNTextObservation, in imageSize: CGSize) -> CGRect {
        // Special thanks to: https://github.com/g-r-a-n-t/serial-vision/
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: imageSize.width, y: -imageSize.height)
        transform = transform.translatedBy(x: 0, y: -1)

        return CGRect(x: observation.boundingBox.applying(transform).origin.x,
                      y: observation.boundingBox.applying(transform).origin.y,
                      width: observation.boundingBox.applying(transform).width,
                      height: observation.boundingBox.applying(transform).height)
    }
}

private extension Font {
    convenience init?(named fontName: String, fitting text: String, into targetSize: CGSize, with attributes: [NSAttributedString.Key: Any], options: DrawingOptions) {
        var attributes = attributes
        let fontSize = targetSize.height

        attributes[.font] = Font(name: fontName, size: fontSize)
        let size = text.boundingRect(with: CGSize(width: .greatestFiniteMagnitude, height: fontSize),
                                     options: options,
                                     attributes: attributes,
                                     context: nil).size

        let heightSize = targetSize.height / (size.height / fontSize)
        let widthSize = targetSize.width / (size.width / fontSize)

        self.init(name: fontName, size: min(heightSize, widthSize))
    }
}

private extension NSAttributedString {
    static func createCleared(from text: String, with size: CGSize) -> NSAttributedString {
        let fontName = Font.systemFont(ofSize: 0).fontName
        var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.foregroundColor: Color.clear]
        let theFont = Font(named: fontName, fitting: text, into: size, with: attributes, options: .usesFontLeading)
        attributes[.font] = theFont
        let actualWidth = NSAttributedString(string: text, attributes: attributes).size()
        // 100% width causes font ligatures to clip; 1/4 of an em adds enough slack.
        // swiftlint:disable:next identifier_name
        let em = actualWidth.width / CGFloat(text.count)
        attributes[NSAttributedString.Key.expansion] = log(size.width / (actualWidth.width + em / 4))

        return NSAttributedString(string: text, attributes: attributes)
    }
}
