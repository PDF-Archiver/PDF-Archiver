//
//  PDFMetadataTests.swift
//  ArchiverLib
//

import ArchiverModels
import Foundation
import PDFKit
import Testing

@testable import DocumentProcessingPipeline

struct PDFMetadataTests {

    private let marker = "PDF Archiver"
    private let tempFolder: URL

    init() throws {
        tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true, attributes: nil)
    }

    private func copyToTemp(_ source: URL, name: String) throws -> URL {
        let dest = tempFolder.appendingPathComponent(name)
        let data = try Data(contentsOf: source)
        try data.write(to: dest)
        return dest
    }

    private func writeToTemp(_ pdf: PDFDocument, name: String) -> URL {
        let dest = tempFolder.appendingPathComponent(name)
        pdf.write(to: dest)
        return dest
    }

    // MARK: - hasTextLayer

    @Test
    func hasTextLayerReturnsTrueForTextPDF() throws {
        let pdf = try #require(PDFDocument(url: Bundle.longTextPDFUrl))
        #expect(PDFMetadata.hasTextLayer(pdf))
    }

    @Test
    func hasTextLayerReturnsTrueForBillPDF() throws {
        let pdf = try #require(PDFDocument(url: Bundle.billPDFUrl))
        #expect(PDFMetadata.hasTextLayer(pdf))
    }

    @Test
    func hasTextLayerReturnsFalseForImageOnlyPDF() throws {
        let image = try #require(PlatformImage(contentsOf: Bundle.billPNGUrl))
        let pdf = Self.createImageOnlyPDF(from: image)
        #expect(!PDFMetadata.hasTextLayer(pdf))
    }

    @Test
    func hasTextLayerRespectsMaxPages() throws {
        let pdf = try #require(PDFDocument(url: Bundle.longTextPDFUrl))
        #expect(PDFMetadata.hasTextLayer(pdf, maxPages: 1))
    }

    @Test
    func hasTextLayerReturnsFalseForBrokenTextLayer() throws {
        // A German paragraph run through the substitution alphabet of a real
        // broken `ToUnicode` CMap: the page carries plenty of text, but no
        // search and no language model can use it.
        let mojibake = """
        Aaz6§naaz6,a§U3mar§HrK§9a66arff§3r1ai§a6z3t,ar§Aia§Kia§Fa7zrHrn§sHa6§Kia§$iasa6Hrn§dbm§ta,Z,ar\
        §pbr3,fl§4i,,a§Ha1a6laigar§Aia§Kar§4a,63n§irra6z3t1§dbr§dia6Zazr§W3nar§3Hs§K3g§Hr,ar§nar3rr,a\
        §übr,bfl§Piatar§U3r.§sHa6§_z6§Pa6,63Har§HrK§_z6a§4ag,attHrn§1ai§Hrga6am§Lr,a6razmarfl
        """
        let pdf = Self.createTextPDF(mojibake)

        try #require(pdf.page(at: 0)?.string?.isEmpty == false, "the fixture must actually carry text")
        #expect(!PDFMetadata.hasTextLayer(pdf))
    }

    /// The readability check must not reject the app's own OCR output — that
    /// would re-OCR every scanned document on every pass.
    @Test(.tags(.ocr))
    func hasTextLayerReturnsTrueAfterOwnOCR() async throws {
        let image = try #require(PlatformImage(contentsOf: Bundle.billPNGUrl))
        let pdf = Self.createImageOnlyPDF(from: image)
        try #require(!PDFMetadata.hasTextLayer(pdf))

        try await PDFOCREngine.addTextLayer(to: pdf, quality: .lossless)

        #expect(PDFMetadata.hasTextLayer(pdf))
    }

    // MARK: - isMarked

    @Test
    func wasProcessedReturnsFalseForExternalPDF() throws {
        let pdf = try #require(PDFDocument(url: Bundle.longTextPDFUrl))
        #expect(!PDFMetadata.isMarked(pdf, markerPrefix: marker))
    }

    @Test
    func wasProcessedReturnsFalseForBillPDF() throws {
        let pdf = try #require(PDFDocument(url: Bundle.billPDFUrl))
        #expect(!PDFMetadata.isMarked(pdf, markerPrefix: marker))
    }

    @Test
    func wasProcessedReturnsTrueAfterMarking() throws {
        let url = try copyToTemp(Bundle.billPDFUrl, name: "marked.pdf")
        let pdf = try #require(PDFDocument(url: url))

        PDFMetadata.markAsProcessed(pdf, marker: marker, writeTo: url)

        let reloaded = try #require(PDFDocument(url: url))
        #expect(PDFMetadata.isMarked(reloaded, markerPrefix: marker))
    }

    @Test
    func wasProcessedReturnsFalseWithoutCreator() {
        let pdf = PDFDocument()
        pdf.documentAttributes = [:]
        #expect(!PDFMetadata.isMarked(pdf, markerPrefix: marker))
    }

    // MARK: - markAsProcessed

    @Test
    func markAsProcessedSetsCreatorAttribute() throws {
        let url = try copyToTemp(Bundle.billPDFUrl, name: "creator-test.pdf")
        let pdf = try #require(PDFDocument(url: url))

        PDFMetadata.markAsProcessed(pdf, marker: marker, writeTo: url)

        let reloaded = try #require(PDFDocument(url: url))
        let creator = try #require(reloaded.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String)
        #expect(creator.hasPrefix(marker))
    }

    @Test
    func markAsProcessedOverwritesExistingCreator() throws {
        let url = try copyToTemp(Bundle.billPDFUrl, name: "overwrite-test.pdf")
        let pdf = try #require(PDFDocument(url: url))

        PDFMetadata.markAsProcessed(pdf, marker: marker, writeTo: url)

        let reloaded = try #require(PDFDocument(url: url))
        let creator = try #require(reloaded.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String)
        #expect(creator.hasPrefix(marker))
    }

    @Test
    func markAsProcessedWritesReadableFile() throws {
        let url = try copyToTemp(Bundle.billPDFUrl, name: "writable-test.pdf")
        let pdf = try #require(PDFDocument(url: url))
        let originalPageCount = pdf.pageCount

        PDFMetadata.markAsProcessed(pdf, marker: marker, writeTo: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let reloaded = try #require(PDFDocument(url: url))
        #expect(reloaded.pageCount == originalPageCount)
    }

    // MARK: - Helpers

    /// Create a single-page PDF containing only `text` for testing.
    static func createTextPDF(_ text: String) -> PDFDocument {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
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
        #else
        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.current = previousContext }
        let font = NSFont.systemFont(ofSize: 11)
        #endif

        context.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height))
        NSAttributedString(string: text, attributes: [.font: font]).draw(in: bounds.insetBy(dx: 40, dy: 40))
        context.endPDFPage()
        context.closePDF()

        // swiftlint:disable:next force_unwrapping
        return PDFDocument(data: data as Data)!
    }

    /// Create a PDF containing only an image (no text layer) for testing.
    static func createImageOnlyPDF(from image: PlatformImage) -> PDFDocument {
        let bounds = CGRect(origin: .zero, size: image.size)
        let data = NSMutableData()
        // swiftlint:disable force_unwrapping
        let consumer = CGDataConsumer(data: data)!
        var mediaBox = bounds
        let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
        // swiftlint:enable force_unwrapping

        context.beginPDFPage(nil)
        #if canImport(UIKit)
        UIGraphicsPushContext(context)
        image.draw(in: bounds)
        UIGraphicsPopContext()
        #else
        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: bounds)
        NSGraphicsContext.current = previousContext
        #endif
        context.endPDFPage()
        context.closePDF()

        // swiftlint:disable:next force_unwrapping
        return PDFDocument(data: data as Data)!
    }
}
