//
//  DocumentProcessingPipelineTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import ContentExtractorStore
import Dependencies
@testable import DocumentProcessingPipeline
import Foundation
import Testing

@Suite
struct DocumentProcessingPipelineTests {

    private func makeConfig(
        urls: [URL] = [],
        steps: Set<PipelineConfiguration.StepKind> = [.ocr, .aiCache]
    ) -> PipelineConfiguration {
        PipelineConfiguration(
            urls: urls,
            steps: steps
        )
    }

    @Test
    func processAndWaitRunsOCRStep() async {
        let pipeline = DocumentProcessingPipeline()
        let config = makeConfig(steps: [.ocr])
        let result = await pipeline.processAndWait(config)

        // OCR step runs but no URLs to process
        #expect(result.stepResults.count == 1)
        #expect(result.stepResults[0].step == .ocr)
        #expect(result.stepResults[0].processedCount == 0)
    }

    @Test
    func processAndWaitSkipsStepsNotInConfig() async {
        let pipeline = DocumentProcessingPipeline()
        // Only request OCR, AI cache should be skipped
        let config = makeConfig(steps: [.ocr])
        let result = await pipeline.processAndWait(config)

        #expect(result.stepResults.count == 1)
        #expect(result.stepResults[0].step == .ocr)
    }

    @Test
    func processAndWaitRunsAICacheStep() async {
        await withDependencies {
            $0.archiveStore.getDocuments = { [] }
            $0.contentExtractorStore.pruneCache = { _ in }
        } operation: {
            let pipeline = DocumentProcessingPipeline()
            let config = makeConfig(steps: [.aiCache])
            let result = await pipeline.processAndWait(config)

            #expect(result.stepResults.count == 1)
            #expect(result.stepResults[0].step == .aiCache)
            #expect(result.stepResults[0].processedCount == 0)
        }
    }

    @Test
    func processEmitsStatusUpdates() async {
        let pipeline = DocumentProcessingPipeline()
        let config = makeConfig(steps: [.ocr])

        var updates: [DocumentProcessingPipeline.StatusUpdate] = []
        for await update in await pipeline.process(config) {
            updates.append(update)
        }

        // No URLs means no status updates
        #expect(updates.isEmpty)
    }

    @Test
    func processAndWaitReturnsEmptyForNoSteps() async {
        let pipeline = DocumentProcessingPipeline()
        let config = makeConfig(steps: [])
        let result = await pipeline.processAndWait(config)

        #expect(result.stepResults.isEmpty)
    }

    @Test
    func pdfTextExtractorDetectsText() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        let pdf = createPDFWithText("Hello World")
        try #require(pdf.write(to: url))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(PDFTextExtractor.extractText(from: url) != nil)
    }

    @Test
    func pdfTextExtractorReturnsNilForBlankPDF() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        let pdf = createBlankPDF()
        try #require(pdf.write(to: url))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(PDFTextExtractor.extractText(from: url) == nil)
    }

    @Test
    func pdfTextExtractorReturnsNilForNonexistentFile() {
        let result = PDFTextExtractor.extractText(from: URL(fileURLWithPath: "/nonexistent.pdf"))
        #expect(result == nil)
    }
}

// MARK: - Test Helpers

import PDFKit

private func createPDFWithText(_ text: String) -> PDFDocument {
    let data = NSMutableData()
    var bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(data: data),
          let context = CGContext(consumer: consumer, mediaBox: &bounds, nil) else {
        fatalError("Failed to create PDF context")
    }

    context.beginPDFPage(nil)

    let attributes: [NSAttributedString.Key: Any] = [
        .font: platformFont(size: 12)
    ]
    let attributedString = NSAttributedString(string: text, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributedString)
    context.textPosition = CGPoint(x: 50, y: 700)
    CTLineDraw(line, context)

    context.endPDFPage()
    context.closePDF()

    return PDFDocument(data: data as Data) ?? PDFDocument()
}

private func createBlankPDF() -> PDFDocument {
    let data = NSMutableData()
    var bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(data: data),
          let context = CGContext(consumer: consumer, mediaBox: &bounds, nil) else {
        fatalError("Failed to create PDF context")
    }

    context.beginPDFPage(nil)
    context.endPDFPage()
    context.closePDF()

    return PDFDocument(data: data as Data) ?? PDFDocument()
}

#if canImport(UIKit)
import UIKit
private func platformFont(size: CGFloat) -> UIFont {
    UIFont.systemFont(ofSize: size)
}
#else
import AppKit
private func platformFont(size: CGFloat) -> NSFont {
    NSFont.systemFont(ofSize: size)
}
#endif
