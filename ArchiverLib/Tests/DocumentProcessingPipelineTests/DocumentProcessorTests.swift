//
//  DocumentProcessorTests.swift
//  ArchiverLib
//

import ArchiverModels
import ContentExtractorStore
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

    // MARK: - Feature print caching (stage 3)

    @Test
    func untaggedProcessingCachesAFeaturePrintAlongsideTheAiPass() async throws {
        // Feature-print caching only runs alongside the AI pass, which is gated to the OS this
        // package's `ContentExtractorStore` requires.
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let cache = FeaturePrintCache.inMemory()
        let processor = DocumentProcessor(stagingFolder: stagingFolder, featurePrintCache: cache)
        let document = Document.mock(url: Bundle.billPDFUrl, isTagged: false, downloadStatus: 1)

        _ = await processor.processUntaggedDocuments(in: [document], config: config, ocr: false, aiContext: AIContext())

        let entry = await cache.load(document.id)
        #expect(entry != nil)
        #expect(entry?.revision == FeaturePrintCache.currentRevision)
    }

    @Test
    func untaggedProcessingSkipsAnAlreadyCachedFeaturePrint() async throws {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let cache = FeaturePrintCache.inMemory()
        let document = Document.mock(url: Bundle.billPDFUrl, isTagged: false, downloadStatus: 1)
        let sentinel = FeaturePrintCache.Entry(documentID: document.id, encodedObservation: Data([9, 9, 9]), revision: FeaturePrintCache.currentRevision)
        await cache.save(sentinel)
        let processor = DocumentProcessor(stagingFolder: stagingFolder, featurePrintCache: cache)

        _ = await processor.processUntaggedDocuments(in: [document], config: config, ocr: false, aiContext: AIContext())

        // Untouched, not recomputed: the sentinel bytes prove the cached entry was never replaced.
        #expect(await cache.load(document.id)?.encodedObservation == Data([9, 9, 9]))
    }

    @Test
    func untaggedProcessingRecomputesAStaleRevisionPrint() async throws {
        // The bug this guards: `== nil` skipped on presence alone, so a print stamped with a
        // revision older than `FeaturePrintCache.currentRevision` (e.g. after a Vision revision
        // bump) would never be recomputed, and `VisualNeighbourFinder` would reject it forever.
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let cache = FeaturePrintCache.inMemory()
        let document = Document.mock(url: Bundle.billPDFUrl, isTagged: false, downloadStatus: 1)
        let stale = FeaturePrintCache.Entry(documentID: document.id, encodedObservation: Data([9, 9, 9]), revision: FeaturePrintCache.currentRevision - 1)
        await cache.save(stale)
        let processor = DocumentProcessor(stagingFolder: stagingFolder, featurePrintCache: cache)

        _ = await processor.processUntaggedDocuments(in: [document], config: config, ocr: false, aiContext: AIContext())

        let entry = await cache.load(document.id)
        #expect(entry?.revision == FeaturePrintCache.currentRevision)
        #expect(entry?.encodedObservation != Data([9, 9, 9]))
    }

    @Test
    func untaggedProcessingBackfillsFeaturePrintsForTaggedDocuments() async throws {
        // The bug this guards: only `untaggedDocuments` were ever passed here, but
        // `VisualNeighbourFinder` reads only tagged rows - so a document tagged before this
        // shipped would never get a print, and the visual channel stayed inert for it forever.
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let cache = FeaturePrintCache.inMemory()
        let processor = DocumentProcessor(stagingFolder: stagingFolder, featurePrintCache: cache)
        let tagged = Document.mock(url: Bundle.billPDFUrl, isTagged: true, downloadStatus: 1)

        _ = await processor.processUntaggedDocuments(in: [tagged], config: config, ocr: false, aiContext: AIContext())

        let entry = await cache.load(tagged.id)
        #expect(entry != nil)
        #expect(entry?.revision == FeaturePrintCache.currentRevision)
    }

    @Test
    func untaggedProcessingBoundsTheTaggedBackfillPerPass() async throws {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let cache = FeaturePrintCache.inMemory()
        let processor = DocumentProcessor(stagingFolder: stagingFolder, featurePrintCache: cache)
        // Distinct ids, same underlying file - only the count of backfilled entries matters here.
        let taggedDocuments = (0..<(DocumentProcessor.taggedFeaturePrintBackfillBudget + 1)).map { index in
            Document(id: index, rootKey: "test", url: Bundle.billPDFUrl, date: Date(), specification: "doc\(index)", tags: [], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
        }

        _ = await processor.processUntaggedDocuments(in: taggedDocuments, config: config, ocr: false, aiContext: AIContext())

        var cachedCount = 0
        for document in taggedDocuments where await cache.load(document.id) != nil {
            cachedCount += 1
        }
        #expect(cachedCount == DocumentProcessor.taggedFeaturePrintBackfillBudget)
    }

    @Test
    func noFeaturePrintIsCachedWithoutAiContext() async throws {
        let cache = FeaturePrintCache.inMemory()
        let processor = DocumentProcessor(stagingFolder: stagingFolder, featurePrintCache: cache)
        let document = Document.mock(url: Bundle.billPDFUrl, isTagged: false, downloadStatus: 1)

        _ = await processor.processUntaggedDocuments(in: [document], config: config, ocr: false, aiContext: nil)

        #expect(await cache.load(document.id) == nil)
    }

    // MARK: - Retrieval wiring (the background AI pass must use the same finders as init got)

    @Test
    func theBackgroundAiPassQueriesTheInjectedNeighbourFinder() async throws {
        // The bug this guards: the background pass built its own `ContentExtractorStore` with
        // `.unavailable` finders, ignoring whatever `DocumentProcessor.init` was given - the cache
        // entries it wrote then carried the pre-retrieval prompt forever.
        //
        // `retrieveNeighbours` sits behind `extract()`'s Apple Intelligence availability gate, not
        // just an OS-version check, so this only asserts when the model is genuinely usable here -
        // otherwise it would fail on "AI is off" and prove nothing about the wiring.
        guard #available(iOS 26.0, macOS 26.0, *), ContentExtractorStore.getAvailability().isUsable else { return }
        let calls = CallRecorder()
        let finder = NeighbourFinder { _, _, _ in
            await calls.record()
            return []
        }
        let processor = DocumentProcessor(stagingFolder: stagingFolder,
                                          suggestionCache: .unavailable,
                                          neighbourFinder: finder)
        let document = Document.mock(url: Bundle.billPDFUrl, isTagged: false, downloadStatus: 1)

        _ = await processor.processUntaggedDocuments(in: [document], config: config, ocr: false, aiContext: AIContext())

        #expect(await calls.wasCalled, "The background pass never reached the injected neighbourFinder")
    }
}

/// Records whether a `@Sendable` closure was ever invoked - a plain `var` capture would be a data
/// race under strict concurrency.
private actor CallRecorder {
    private(set) var wasCalled = false
    func record() { wasCalled = true }
}
