//
//  DocumentProcessingPipelineTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import ArchiverModels
@testable import DocumentProcessingPipeline
import Testing

struct MockStep: DocumentProcessingStep, @unchecked Sendable {
    let name: String
    let isEnabled: Bool
    var processHandler: @Sendable (DocumentProcessingContext) async -> Int

    func process(context: DocumentProcessingContext) async -> DocumentProcessingStepResult {
        let count = await processHandler(context)
        return DocumentProcessingStepResult(stepName: name, documentsProcessed: count)
    }
}

@Suite
struct DocumentProcessingPipelineTests {

    private func makeContext(documents: [Document] = []) -> DocumentProcessingContext {
        DocumentProcessingContext(
            documents: documents,
            textExtractor: { _ in nil },
            customPrompt: nil
        )
    }

    @Test
    func runsEnabledStepsSequentially() async {
        var executionOrder: [String] = []
        let step1 = MockStep(name: "Step1", isEnabled: true) { _ in
            executionOrder.append("Step1")
            return 2
        }
        let step2 = MockStep(name: "Step2", isEnabled: true) { _ in
            executionOrder.append("Step2")
            return 3
        }

        let pipeline = DocumentProcessingPipeline(steps: [step1, step2])
        let results = await pipeline.run(context: makeContext())

        #expect(results.count == 2)
        #expect(results[0].stepName == "Step1")
        #expect(results[0].documentsProcessed == 2)
        #expect(results[1].stepName == "Step2")
        #expect(results[1].documentsProcessed == 3)
        #expect(executionOrder == ["Step1", "Step2"])
    }

    @Test
    func skipsDisabledSteps() async {
        let enabledStep = MockStep(name: "Enabled", isEnabled: true) { _ in 1 }
        let disabledStep = MockStep(name: "Disabled", isEnabled: false) { _ in 99 }

        let pipeline = DocumentProcessingPipeline(steps: [disabledStep, enabledStep])
        let results = await pipeline.run(context: makeContext())

        #expect(results.count == 1)
        #expect(results[0].stepName == "Enabled")
    }

    @Test
    func returnsEmptyResultsWhenAllDisabled() async {
        let step = MockStep(name: "Disabled", isEnabled: false) { _ in 0 }

        let pipeline = DocumentProcessingPipeline(steps: [step])
        let results = await pipeline.run(context: makeContext())

        #expect(results.isEmpty)
    }

    @Test
    func returnsEmptyResultsWhenNoSteps() async {
        let pipeline = DocumentProcessingPipeline(steps: [])
        let results = await pipeline.run(context: makeContext())

        #expect(results.isEmpty)
    }

    @Test
    func passesContextToSteps() async {
        let doc = Document.mock()
        var receivedDocumentCount = 0

        let step = MockStep(name: "Check", isEnabled: true) { context in
            receivedDocumentCount = context.documents.count
            return 0
        }

        let pipeline = DocumentProcessingPipeline(steps: [step])
        let context = DocumentProcessingContext(
            documents: [doc],
            textExtractor: { _ in "test" },
            customPrompt: "custom"
        )
        _ = await pipeline.run(context: context)

        #expect(receivedDocumentCount == 1)
    }

    @Test
    func ocrStepPdfHasTextDetection() {
        // Test the pdfHasText helper with a simple in-memory PDF
        let step = OCRProcessingStep()

        // Create a PDF with text
        let pdfWithText = createPDFWithText("Hello World")
        #expect(step.pdfHasText(pdfWithText))

        // Create a blank PDF (no text)
        let blankPDF = createBlankPDF()
        #expect(!step.pdfHasText(blankPDF))
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
    // Draw nothing - just a blank page
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
