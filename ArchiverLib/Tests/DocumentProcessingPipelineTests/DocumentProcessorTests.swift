//
//  DocumentProcessorTests.swift
//  ArchiverLib
//

import ArchiverModels
import Foundation
import PDFKit
import Testing

@testable import DocumentProcessingPipeline

struct DocumentProcessorTests {

    private let stagingFolder: URL
    private let destinationFolder: URL
    private let config: ProcessingConfig

    init() throws {
        let tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        stagingFolder = tempFolder.appendingPathComponent("staging")
        destinationFolder = tempFolder.appendingPathComponent("untagged")
        try FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true, attributes: nil)
        config = ProcessingConfig(destinationFolder: destinationFolder,
                                  pdfQuality: .lossless,
                                  processedMarker: "PDF Archiver")
    }

    private func destinationContents() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: destinationFolder, includingPropertiesForKeys: nil)
    }

    private func stagingContents() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: stagingFolder, includingPropertiesForKeys: nil)
    }

    // MARK: - PDF import

    @Test
    func importPdfMovesFileToDestinationWithPlaceholderName() async throws {
        let processor = DocumentProcessor(stagingFolder: stagingFolder)
        let pdfData = try Data(contentsOf: Bundle.billPDFUrl)
        let originalText = try #require(PDFDocument(data: pdfData)?.string)

        await processor.importPdf(pdfData, filename: "document1.pdf", config: config)
        await processor.waitForQueue()

        let created = try #require(try destinationContents().first)
        // "document1.pdf" does not follow the naming scheme, so a placeholder name is generated.
        #expect(created.lastPathComponent.contains(Document.descriptionPlaceholder.lowercased()))
        #expect(created.lastPathComponent.contains(Document.tagPlaceholder.lowercased()))

        // The file is moved as-is: content stays byte-identical.
        #expect(try Data(contentsOf: created) == pdfData)
        #expect(PDFDocument(url: created)?.string == originalText)

        // Delete-after-success: the staged copy is gone.
        #expect(try stagingContents().isEmpty)
    }

    @Test
    func importPdfKeepsParseableFilename() async throws {
        let processor = DocumentProcessor(stagingFolder: stagingFolder)
        let pdfData = try Data(contentsOf: Bundle.billPDFUrl)

        await processor.importPdf(pdfData, filename: "2019-10-01--avb-plusgarantie__zurich.pdf", config: config)
        await processor.waitForQueue()

        let created = try #require(try destinationContents().first)
        #expect(created.lastPathComponent == "2019-10-01--avb-plusgarantie__zurich.pdf")
    }

    @Test
    func importInvalidPdfKeepsStagedFile() async throws {
        let processor = DocumentProcessor(stagingFolder: stagingFolder)

        await processor.importPdf(Data("not a pdf".utf8), filename: "broken.pdf", config: config)
        await processor.waitForQueue()

        // Nothing was created, the staged file stays for the next launch.
        #expect((try? destinationContents())?.isEmpty ?? true)
        #expect(try stagingContents().count == 1)
    }

    // MARK: - Staged files

    @Test
    func processStagedFilesPicksUpPdf() async throws {
        let pdfData = try Data(contentsOf: Bundle.billPDFUrl)
        try pdfData.write(to: stagingFolder.appendingPathComponent("external.pdf"))
        let processor = DocumentProcessor(stagingFolder: stagingFolder)

        await processor.processStagedFiles(config: config)
        await processor.waitForQueue()

        #expect(try destinationContents().count == 1)
        #expect(try stagingContents().isEmpty)
    }

    @Test
    func processStagedFilesDoesNotDoubleProcessInFlightFiles() async throws {
        let pdfData = try Data(contentsOf: Bundle.billPDFUrl)
        try pdfData.write(to: stagingFolder.appendingPathComponent("external.pdf"))
        let processor = DocumentProcessor(stagingFolder: stagingFolder)

        // Two triggers in a row - the second must not enqueue the same file again.
        await processor.processStagedFiles(config: config)
        await processor.processStagedFiles(config: config)
        await processor.waitForQueue()

        #expect(try destinationContents().count == 1)
    }

    // MARK: - Progress events

    @Test
    func eventsReportQueueProgress() async throws {
        let processor = DocumentProcessor(stagingFolder: stagingFolder)
        let stream = await processor.events()
        let pdfData = try Data(contentsOf: Bundle.billPDFUrl)

        await processor.importPdf(pdfData, filename: "document1.pdf", config: config)

        var events = [ProcessingEvent]()
        for await event in stream {
            events.append(event)
            if case .finished = event { break }
            if case .failed = event { break }
        }

        guard case .queued(let queuedSource) = events.first else {
            Issue.record("First event should be .queued, got \(events)")
            return
        }
        guard case .finished(let source, let document) = events.last else {
            Issue.record("Last event should be .finished, got \(events)")
            return
        }
        #expect(queuedSource == source)
        #expect(events.contains(.processing(source: source)))
        #expect(document.deletingLastPathComponent().path == destinationFolder.path)
    }

    // MARK: - Staging batches

    @Test
    func stagedScanPagesAreGroupedIntoOneBatch() throws {
        let pageData = Data("fake jpeg".utf8)
        let urls = try Staging.persist(imageJpegs: [pageData, pageData, pageData], in: stagingFolder)
        #expect(urls.count == 3)

        let batches = Staging.batches(in: stagingFolder)
        #expect(batches.count == 1)
        guard case .images(let imageUrls) = try #require(batches.first) else {
            Issue.record("Expected an images batch")
            return
        }
        // Compare filenames: enumeration may resolve the /var -> /private/var symlink.
        #expect(imageUrls.map(\.lastPathComponent) == urls.map(\.lastPathComponent))
    }

    @Test
    func foreignImagesBecomeSinglePageBatches() throws {
        try Data("fake jpeg".utf8).write(to: stagingFolder.appendingPathComponent("photo.jpg"))
        try Data("fake jpeg".utf8).write(to: stagingFolder.appendingPathComponent("scan.jpeg"))

        let batches = Staging.batches(in: stagingFolder)
        #expect(batches.count == 2)
        #expect(batches.allSatisfy { batch in
            if case .images(let urls) = batch { return urls.count == 1 }
            return false
        })
    }

    @Test
    func batchesOfMissingFolderAreEmpty() {
        let missing = stagingFolder.appendingPathComponent("does-not-exist")
        #expect(Staging.batches(in: missing).isEmpty)
    }

    // MARK: - Filename generation

    @Test
    func filenameGeneratorReusesParseableName() async {
        let filename = await FilenameGenerator.filename(reusing: "2024-05-12--rechnung__auto_werkstatt.pdf")
        #expect(filename == "2024-05-12--rechnung__auto_werkstatt.pdf")
    }

    @Test
    func filenameGeneratorCreatesPlaceholderNameOtherwise() async {
        let filename = await FilenameGenerator.filename(reusing: "Scan 2024-05-12.pdf")
        #expect(filename.contains(Document.descriptionPlaceholder.lowercased()))
        #expect(filename.contains(Document.tagPlaceholder.lowercased()))
        #expect(filename.hasSuffix(".pdf"))
    }
}
