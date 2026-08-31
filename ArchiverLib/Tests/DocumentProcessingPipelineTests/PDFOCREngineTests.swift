//
//  PDFOCREngineTests.swift
//  ArchiverLib
//

import ArchiverModels
import Foundation
import PDFKit
import Testing

@testable import DocumentProcessingPipeline

struct PDFOCREngineTests {

    private let config: ProcessingConfig
    private let tempFolder: URL

    init() throws {
        tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true, attributes: nil)
        config = ProcessingConfig(destinationFolder: tempFolder.appendingPathComponent("out"),
                                  pdfQuality: .lossless,
                                  processedMarker: "PDF Archiver")
    }

    private func writeImageOnlyPDF(name: String) throws -> URL {
        // Use the bill PDF rendered at high resolution for reliable OCR.
        let sourcePdf = try #require(PDFDocument(url: Bundle.billPDFUrl))
        let sourcePage = try #require(sourcePdf.page(at: 0))
        let bounds = sourcePage.bounds(for: .mediaBox)
        let image = sourcePage.thumbnail(of: CGSize(width: bounds.width * 3, height: bounds.height * 3), for: .mediaBox)

        let pdf = PDFMetadataTests.createImageOnlyPDF(from: image)
        let dest = tempFolder.appendingPathComponent(name)
        pdf.write(to: dest)
        return dest
    }

    /// A page whose only content is one full-page JPEG XObject — the shape a
    /// scanner or an import of a photographed document produces.
    ///
    /// Assembled byte by byte because a `CGPDFContext` re-encodes what is drawn
    /// into it and would not necessarily produce a `DCTDecode` stream.
    private func writeJpegImageOnlyPDF(name: String) throws -> (url: URL, pixelSize: CGSize) {
        let image = try #require(PlatformImage(contentsOf: Bundle.billPNGUrl))
        let jpeg = try #require(image.jpg(quality: 0.8))
        let jpegImage = try #require(PlatformImage(data: jpeg))
        let cgImage = try #require(jpegImage.cgImage)
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        // The image spans the whole page, which is what the reuse path requires.
        let pageSize = CGSize(width: 595, height: (595 * pixelSize.height / pixelSize.width).rounded())

        let content = Data("q \(pageSize.width) 0 0 \(pageSize.height) 0 0 cm /Im0 Do Q\n".utf8)
        let objects: [Data] = [
            Data("<< /Type /Catalog /Pages 2 0 R >>".utf8),
            Data("<< /Type /Pages /Kids [3 0 R] /Count 1 >>".utf8),
            Data("""
            << /Type /Page /Parent 2 0 R /MediaBox [0 0 \(pageSize.width) \(pageSize.height)] \
            /Resources << /XObject << /Im0 5 0 R >> >> /Contents 4 0 R >>
            """.utf8),
            Data("<< /Length \(content.count) >>\nstream\n".utf8) + content + Data("\nendstream".utf8),
            Data("""
            << /Type /XObject /Subtype /Image /Width \(cgImage.width) /Height \(cgImage.height) \
            /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length \(jpeg.count) >>\nstream\n
            """.utf8) + jpeg + Data("\nendstream".utf8)
        ]

        var pdf = Data("%PDF-1.4\n".utf8)
        var offsets: [Int] = []
        for (index, object) in objects.enumerated() {
            offsets.append(pdf.count)
            pdf.append(Data("\(index + 1) 0 obj\n".utf8))
            pdf.append(object)
            pdf.append(Data("\nendobj\n".utf8))
        }

        let xrefOffset = pdf.count
        pdf.append(Data("xref\n0 \(objects.count + 1)\n0000000000 65535 f \n".utf8))
        for offset in offsets {
            pdf.append(Data(String(format: "%010d 00000 n \n", offset).utf8))
        }
        pdf.append(Data("trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n".utf8))

        let dest = tempFolder.appendingPathComponent(name)
        try pdf.write(to: dest)
        return (dest, pixelSize)
    }

    /// Pixel sizes of every image XObject reachable from `page`, including
    /// those nested in form XObjects.
    private func embeddedImageSizes(of page: PDFPage) -> [CGSize] {
        guard let dictionary = page.pageRef?.dictionary else { return [] }
        return Self.imageSizes(inXObjectsOf: dictionary)
    }

    /// `/Resources` may be inherited from the page tree instead of sitting on
    /// the page itself.
    private static func resolvedResources(of dictionary: CGPDFDictionaryRef) -> CGPDFDictionaryRef? {
        var resources: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources), let resources { return resources }
        var parent: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(dictionary, "Parent", &parent), let parent else { return nil }
        return resolvedResources(of: parent)
    }

    private static func imageSizes(inXObjectsOf dictionary: CGPDFDictionaryRef) -> [CGSize] {
        guard let resources = resolvedResources(of: dictionary) else { return [] }
        var xObjects: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "XObject", &xObjects),
              let xObjects else { return [] }

        var streams: [CGPDFStreamRef] = []
        withUnsafeMutablePointer(to: &streams) { pointer in
            CGPDFDictionaryApplyFunction(
                xObjects,
                { _, object, info in
                guard let info else { return }
                var stream: CGPDFStreamRef?
                guard CGPDFObjectGetValue(object, .stream, &stream),
                      let stream else { return }
                info.assumingMemoryBound(to: [CGPDFStreamRef].self).pointee.append(stream)
                },
                pointer)
        }

        var sizes: [CGSize] = []
        for stream in streams {
            guard let streamDictionary = CGPDFStreamGetDictionary(stream) else { continue }
            var subtype: UnsafePointer<CChar>?
            guard CGPDFDictionaryGetName(streamDictionary, "Subtype", &subtype),
                  let subtype else { continue }

            switch String(cString: subtype) {
            case "Image":
                var width: CGPDFInteger = 0
                var height: CGPDFInteger = 0
                guard CGPDFDictionaryGetInteger(streamDictionary, "Width", &width),
                      CGPDFDictionaryGetInteger(streamDictionary, "Height", &height) else { continue }
                sizes.append(CGSize(width: width, height: height))

            case "Form":
                sizes.append(contentsOf: imageSizes(inXObjectsOf: streamDictionary))

            default:
                continue
            }
        }
        return sizes
    }

    // MARK: - Broken text layer repair

    /// The whole point of #319: a document whose text layer extracts as
    /// mojibake can be repaired, which the permanent `Creator` marker used to
    /// make impossible.
    @Test(.tags(.ocr))
    func forcedRunReplacesAnUnreadableTextLayer() async throws {
        // A German paragraph run through the substitution alphabet of a real
        // broken `ToUnicode` CMap, drawn invisibly over a scanned page.
        let mojibake = "Aaz6§naaz6,a§U3mar§HrK§9a66arff§3r1ai§a6z3t,ar§Aia§Kia§Fa7zrHrn§sHa6§Kia§$iasa6Hrn"
        let image = try #require(PlatformImage(contentsOf: Bundle.billPNGUrl))
        let url = tempFolder.appendingPathComponent("mojibake.pdf")
        Self.createImagePDF(from: image, invisibleText: mojibake).write(to: url)

        let pdf = try #require(PDFDocument(url: url))
        let textBefore = try #require(pdf.page(at: 0)?.string)
        #expect(!TextReadability.isReadable(textBefore))

        #expect(await DocumentProcessor.addOcrTextLayer(at: url, config: config, force: true) == true)

        let repaired = try #require(PDFDocument(url: url))
        let textAfter = try #require(repaired.page(at: 0)?.string)
        #expect(TextReadability.isReadable(textAfter))
    }

    /// A scanned page that additionally carries an invisible (and here
    /// unreadable) text layer.
    private static func createImagePDF(from image: PlatformImage, invisibleText: String) -> PDFDocument {
        let bounds = CGRect(origin: .zero, size: image.size)
        let data = NSMutableData()
        var mediaBox = bounds
        // swiftlint:disable force_unwrapping
        let consumer = CGDataConsumer(data: data)!
        let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
        // swiftlint:enable force_unwrapping

        context.beginPDFPage(nil)
        #if canImport(UIKit)
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        let font = UIFont.systemFont(ofSize: 11)
        let clear = UIColor.clear
        #else
        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.current = previousContext }
        let font = NSFont.systemFont(ofSize: 11)
        let clear = NSColor.clear
        #endif

        image.draw(in: bounds)
        NSAttributedString(string: invisibleText, attributes: [.font: font, .foregroundColor: clear])
            .draw(in: bounds.insetBy(dx: 40, dy: 40))
        context.endPDFPage()
        context.closePDF()

        // swiftlint:disable:next force_unwrapping
        return PDFDocument(data: data as Data)!
    }

    // MARK: - Image reuse

    /// Re-rasterizing an already-rasterized scan degrades it a second time, so
    /// an image-only page must keep its own bitmap.
    @Test(.tags(.ocr))
    func addTextLayerReusesTheImageOfAnImageOnlyPage() async throws {
        let fixture = try writeJpegImageOnlyPDF(name: "image-reuse.pdf")
        let pdf = try #require(PDFDocument(url: fixture.url))
        let boundsBefore = try #require(pdf.page(at: 0)?.bounds(for: .mediaBox))

        try await PDFOCREngine.addTextLayer(to: pdf, quality: .lossless)

        let page = try #require(pdf.page(at: 0))
        #expect(page.bounds(for: .mediaBox) == boundsBefore)
        #expect(embeddedImageSizes(of: page) == [fixture.pixelSize])
    }

    /// A page CoreGraphics cannot hand back verbatim still takes the
    /// rasterization path, which renders at 3x the page size.
    @Test(.tags(.ocr))
    func addTextLayerRasterizesAPageItCannotReuse() async throws {
        let url = try writeImageOnlyPDF(name: "rasterized.pdf")
        let pdf = try #require(PDFDocument(url: url))
        let bounds = try #require(pdf.page(at: 0)?.bounds(for: .mediaBox))

        try await PDFOCREngine.addTextLayer(to: pdf, quality: .lossless)

        let page = try #require(pdf.page(at: 0))
        let renderedSize = try #require(embeddedImageSizes(of: page).first)
        #expect(renderedSize.width == (bounds.width * 3).rounded())
    }

    // MARK: - addTextLayer

    @Test(.tags(.ocr))
    func addTextLayerAddsTextToImageOnlyPDF() async throws {
        let url = try writeImageOnlyPDF(name: "ocr-input.pdf")
        let pdf = try #require(PDFDocument(url: url))
        #expect(!PDFMetadata.hasTextLayer(pdf))

        try await PDFOCREngine.addTextLayer(to: pdf, quality: .lossless)

        #expect(PDFMetadata.hasTextLayer(pdf))
    }

    @Test(.tags(.ocr))
    func addTextLayerPreservesPageCount() async throws {
        let url = try writeImageOnlyPDF(name: "ocr-pagecount.pdf")
        let pdf = try #require(PDFDocument(url: url))
        let originalPageCount = pdf.pageCount

        try await PDFOCREngine.addTextLayer(to: pdf, quality: .lossless)

        #expect(pdf.pageCount == originalPageCount)
    }

    // MARK: - addOcrTextLayer

    @Test
    func passSkipsPDFWithTextLayer() async throws {
        // Copy a text PDF into the temp folder so processIfNeeded would have
        // a writable file to modify if it chose to — it must not.
        let dest = tempFolder.appendingPathComponent("text-pdf.pdf")
        try Data(contentsOf: Bundle.longTextPDFUrl).write(to: dest)
        let creatorBefore = PDFDocument(url: dest)?
            .documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String

        let result = await DocumentProcessor.addOcrTextLayer(at: dest, config: config)

        #expect(result == false)

        // Creator must not be touched when OCR is skipped.
        let creatorAfter = PDFDocument(url: dest)?
            .documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String
        #expect(creatorBefore == creatorAfter)
    }

    @Test
    func passSkipsPDFMarkedByTheCurrentEngineVersion() async throws {
        // Start from an image-only PDF, then mark it as processed manually to
        // simulate a previous failed OCR run.
        let url = try writeImageOnlyPDF(name: "already-marked.pdf")
        let pdf = try #require(PDFDocument(url: url))
        PDFMetadata.markAsProcessed(pdf, marker: config.processedMarker, version: config.ocrEngineVersion, writeTo: url)

        let result = await DocumentProcessor.addOcrTextLayer(at: url, config: config)

        #expect(result == false)
    }

    /// The mass-repair path: an archive stamped by the pre-versioning engine
    /// gets exactly one more attempt once the engine version advances.
    @Test(.tags(.ocr))
    func passRetriesLegacyMarkedPDFAtHigherEngineVersion() async throws {
        let url = try writeImageOnlyPDF(name: "legacy-marked.pdf")
        let pdf = try #require(PDFDocument(url: url))
        pdf.documentAttributes?[PDFDocumentAttribute.creatorAttribute] = config.processedMarker
        pdf.write(to: url)

        var legacyConfig = config
        legacyConfig.ocrEngineVersion = 1
        #expect(await DocumentProcessor.addOcrTextLayer(at: url, config: legacyConfig) == false)

        #expect(await DocumentProcessor.addOcrTextLayer(at: url, config: config) == true)

        // The freshly stamped version stops the following pass.
        #expect(await DocumentProcessor.addOcrTextLayer(at: url, config: config) == false)
    }

    @Test(.tags(.ocr))
    func forcedRunOcrsPDFThatAlreadyHasTextLayer() async throws {
        let dest = tempFolder.appendingPathComponent("forced-text-pdf.pdf")
        try Data(contentsOf: Bundle.billPDFUrl).write(to: dest)

        let result = await DocumentProcessor.addOcrTextLayer(at: dest, config: config, force: true)

        #expect(result == true)
        let reloaded = try #require(PDFDocument(url: dest))
        #expect(PDFMetadata.processedEngineVersion(reloaded, markerPrefix: config.processedMarker) == config.ocrEngineVersion)
    }

    @Test(.tags(.ocr))
    func passMarksImageOnlyPDFAfterOCR() async throws {
        let url = try writeImageOnlyPDF(name: "to-process.pdf")

        let result = await DocumentProcessor.addOcrTextLayer(at: url, config: config)

        #expect(result == true)

        // Reload and verify: text layer added and Creator set.
        let reloaded = try #require(PDFDocument(url: url))
        #expect(PDFMetadata.hasTextLayer(reloaded))
        #expect(PDFMetadata.processedEngineVersion(reloaded, markerPrefix: config.processedMarker) == config.ocrEngineVersion)
    }

    @Test
    func passReturnsFalseForMissingFile() async {
        let missing = tempFolder.appendingPathComponent("does-not-exist.pdf")
        let result = await DocumentProcessor.addOcrTextLayer(at: missing, config: config)
        #expect(result == false)
    }
}
