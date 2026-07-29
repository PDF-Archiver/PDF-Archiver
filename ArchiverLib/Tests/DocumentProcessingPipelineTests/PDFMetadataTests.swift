//
//  PDFMetadataTests.swift
//  ArchiverLib
//

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
