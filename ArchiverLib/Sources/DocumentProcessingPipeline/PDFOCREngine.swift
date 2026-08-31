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
/// - ``addTextLayer(to:quality:maxPages:)`` — the in-place path: image-only
///   pages of an existing PDF are replaced by pages that additionally carry
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

            guard let cgImage = image.cgImage else {
                Logger.ocrProcessing.error("Could not read page image \(url.lastPathComponent, privacy: .public)")
                continue
            }
            let results = try await recognizeText(in: cgImage, imageSize: image.size)
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
        // Pages are rasterized once at 3x their point size (~216 DPI) — enough
        // to preserve the quality of typical scans; rendering at 1x (72 DPI)
        // would irreversibly degrade the user's document.
        let renderScale: CGFloat = 3

        for pageIndex in 0..<min(pdf.pageCount, maxPages) {
            // Cooperative cancellation: a CancellationError here propagates
            // to the caller, which must NOT write the partially-modified pdf.
            try Task.checkCancellation()

            guard let page = pdf.page(at: pageIndex) else { continue }
            let bounds = page.bounds(for: .mediaBox)

            // Rasterizing an already-rasterized scan would degrade it a second
            // time, so an image-only page keeps its original bitmap.
            let ocrImage: PlatformImage
            let drawImage: PlatformImage
            if let reusedImage = imageOnlyPage(page) {
                ocrImage = reusedImage
                drawImage = reusedImage
            } else {
                let renderSize = CGSize(width: bounds.width * renderScale, height: bounds.height * renderScale)
                let pageImage = page.thumbnail(of: renderSize, for: .mediaBox)
                ocrImage = pageImage

                // Re-encode the high-resolution page image as JPEG so the new
                // page does not blow up the file size with a raw bitmap.
                if let jpegData = pageImage.jpg(quality: CGFloat(quality.rawValue)),
                   let jpegImage = PlatformImage(data: jpegData) {
                    drawImage = jpegImage
                } else {
                    drawImage = pageImage
                }
            }

            guard let pageCgImage = ocrImage.cgImage else { continue }
            let ocrResults = try await recognizeText(in: pageCgImage, imageSize: ocrImage.size)
            guard !ocrResults.isEmpty else { continue }

            // Scale OCR coordinates back from the OCR'd image to page
            // coordinates - a reused image has its own, unassumable size.
            let scaleX = bounds.width / ocrImage.size.width
            let scaleY = bounds.height / ocrImage.size.height
            let scaledResults = ocrResults.map { result in
                TextObservationResult(
                    rect: CGRect(x: result.rect.origin.x * scaleX,
                                 y: result.rect.origin.y * scaleY,
                                 width: result.rect.width * scaleX,
                                 height: result.rect.height * scaleY),
                    text: result.text)
            }
            let textEntries = await makeTextEntries(from: scaledResults)

            // Always drawn into the original media box, keeping the page size.
            guard let newPage = renderPage(image: drawImage, bounds: bounds, texts: textEntries) else { continue }
            pdf.removePage(at: pageIndex)
            pdf.insert(newPage, at: pageIndex)
        }
    }

    /// `/Resources` may be inherited from the page tree instead of sitting on
    /// the page itself.
    private static func resolvedResources(of dictionary: CGPDFDictionaryRef) -> CGPDFDictionaryRef? {
        var resources: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources), let resources { return resources }

        var parent: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(dictionary, "Parent", &parent),
              let parent else { return nil }
        return resolvedResources(of: parent)
    }

    /// The page's own bitmap, if the page is nothing but one full-page JPEG.
    ///
    /// Returns `nil` for every other page shape (several XObjects, a vector or
    /// text page, a non-JPEG encoding, a rotated page, an image that does not
    /// span the page) so the caller falls back to rasterizing the page.
    private static func imageOnlyPage(_ page: PDFPage) -> PlatformImage? {
        guard let dictionary = page.pageRef?.dictionary else { return nil }

        // A rotated page needs the rotation the rasterizer applies; reusing the
        // bitmap unrotated would transpose the whole text layer.
        var rotation: CGPDFInteger = 0
        if CGPDFDictionaryGetInteger(dictionary, "Rotate", &rotation), rotation != 0 { return nil }

        var xObjects: CGPDFDictionaryRef?
        guard let resources = resolvedResources(of: dictionary),
              CGPDFDictionaryGetDictionary(resources, "XObject", &xObjects),
              let xObjects,
              CGPDFDictionaryGetCount(xObjects) == 1 else { return nil }

        var stream: CGPDFStreamRef?
        withUnsafeMutablePointer(to: &stream) { pointer in
            CGPDFDictionaryApplyFunction(xObjects, { _, object, info in
                guard let info else { return }
                var candidate: CGPDFStreamRef?
                guard CGPDFObjectGetValue(object, .stream, &candidate),
                      let candidate else { return }
                info.assumingMemoryBound(to: CGPDFStreamRef?.self).pointee = candidate
            }, pointer)
        }

        guard let stream,
              let streamDictionary = CGPDFStreamGetDictionary(stream) else { return nil }

        var subtype: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(streamDictionary, "Subtype", &subtype),
              let subtype,
              String(cString: subtype) == "Image" else { return nil }

        // Only an encoding the stream carries verbatim can be reused; a `.raw`
        // stream is undecodable sample data without its colour space.
        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(stream, &format) as Data?,
              format == .jpegEncoded || format == .JPEG2000,
              let image = PlatformImage(data: data),
              image.size.width > 0, image.size.height > 0 else { return nil }

        // An image that is not the whole page would be stretched over the media
        // box by the renderer.
        let pageBounds = page.bounds(for: .mediaBox)
        let aspectRatio = image.size.width / image.size.height
        let pageAspectRatio = pageBounds.width / pageBounds.height
        guard abs(aspectRatio - pageAspectRatio) < 0.02 * pageAspectRatio else { return nil }

        return image
    }

    // MARK: - Shared core

    /// Run Vision OCR on a single image and return recognized text with positions.
    /// Coordinates are in the image's coordinate system (origin top-left, y-down).
    ///
    /// Uses the Swift `RecognizeTextRequest` (iOS 18 / macOS 15), which is
    /// genuinely `async` - no thread is blocked, so this is safe to await
    /// directly from the cooperative pool. It also recognizes the whole page in
    /// a single Vision call: `RecognizedTextObservation` already carries the
    /// bounding box of each recognized line, which the old
    /// `VNDetectTextRectanglesRequest` + per-box `VNRecognizeTextRequest`
    /// combination needed one extra Vision call per text box to produce.
    ///
    /// - Parameters:
    ///   - cgImage: The image to recognize.
    ///   - imageSize: Size the observation coordinates are mapped into. This is
    ///     the `PlatformImage.size` of the source image, which is not
    ///     necessarily the pixel size of `cgImage`.
    static func recognizeText(in cgImage: CGImage, imageSize: CGSize) async throws -> [TextObservationResult] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let observations = try await request.perform(on: cgImage)

        return observations.compactMap { observation in
            guard observation.confidence > confidenceThreshold,
                  let candidate = observation.topCandidates(1).first,
                  !candidate.string.isEmpty else { return nil }

            // `.upperLeft` matches the y-down coordinate space the renderer draws in.
            let rect = observation.boundingBox.toImageCoordinates(imageSize, origin: .upperLeft)
            return TextObservationResult(rect: rect, text: candidate.string)
        }
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
