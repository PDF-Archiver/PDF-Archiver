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

    // MARK: - addOcrTextLayerIfNeeded

    @Test
    func passSkipsPDFWithTextLayer() async throws {
        // Copy a text PDF into the temp folder so processIfNeeded would have
        // a writable file to modify if it chose to — it must not.
        let dest = tempFolder.appendingPathComponent("text-pdf.pdf")
        try Data(contentsOf: Bundle.longTextPDFUrl).write(to: dest)
        let creatorBefore = PDFDocument(url: dest)?
            .documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String

        let result = await DocumentProcessor.addOcrTextLayerIfNeeded(at: dest, config: config)

        #expect(result == false)

        // Creator must not be touched when OCR is skipped.
        let creatorAfter = PDFDocument(url: dest)?
            .documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String
        #expect(creatorBefore == creatorAfter)
    }

    @Test
    func passSkipsAlreadyMarkedPDF() async throws {
        // Start from an image-only PDF, then mark it as processed manually to
        // simulate a previous failed OCR run.
        let url = try writeImageOnlyPDF(name: "already-marked.pdf")
        let pdf = try #require(PDFDocument(url: url))
        PDFMetadata.markAsProcessed(pdf, marker: config.processedMarker, writeTo: url)

        let result = await DocumentProcessor.addOcrTextLayerIfNeeded(at: url, config: config)

        #expect(result == false)
    }

    @Test(.tags(.ocr))
    func passMarksImageOnlyPDFAfterOCR() async throws {
        let url = try writeImageOnlyPDF(name: "to-process.pdf")

        let result = await DocumentProcessor.addOcrTextLayerIfNeeded(at: url, config: config)

        #expect(result == true)

        // Reload and verify: text layer added and Creator set.
        let reloaded = try #require(PDFDocument(url: url))
        #expect(PDFMetadata.hasTextLayer(reloaded))
        #expect(PDFMetadata.isMarked(reloaded, markerPrefix: config.processedMarker))
    }

    @Test
    func passReturnsFalseForMissingFile() async {
        let missing = tempFolder.appendingPathComponent("does-not-exist.pdf")
        let result = await DocumentProcessor.addOcrTextLayerIfNeeded(at: missing, config: config)
        #expect(result == false)
    }
}
