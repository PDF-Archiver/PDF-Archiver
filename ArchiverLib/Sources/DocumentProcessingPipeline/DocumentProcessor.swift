//
//  DocumentProcessor.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import ArchiverModels
import ContentExtractorStore
import CoreGraphics
import Foundation
import OSLog
import PDFKit

/// Result of one untagged-documents pass.
public struct UntaggedProcessingResult: Sendable, Equatable {
    /// Number of documents that received an OCR text layer.
    public let ocrCount: Int
    /// Number of newly created AI suggestion cache entries.
    public let aiCacheCount: Int

    public init(ocrCount: Int, aiCacheCount: Int) {
        self.ocrCount = ocrCount
        self.aiCacheCount = aiCacheCount
    }
}

/// The single entry point for document processing.
///
/// The actor accepts requests (scanned pages, imported PDF data, files found
/// in the staging folder), serializes them into a FIFO queue, tracks progress
/// via ``events()`` and forwards each request to the processing core. Finished
/// documents are written to the destination folder of the per-request
/// ``ProcessingConfig``.
///
/// # Crash safety
///
/// Every request is persisted in the staging folder before it enters the
/// queue and deleted only after the finished document was written. A crash
/// mid-processing therefore never loses a document — the staged file is
/// picked up by the next ``processStagedFiles(config:)`` run. The in-memory
/// in-flight set prevents a second trigger from double-processing files that
/// are already queued.
///
/// # Queue
///
/// Requests are chained: each queue task first awaits its predecessor, so
/// documents are processed strictly one at a time while intake stays
/// non-blocking. ``importScan(_:config:)`` awaits exactly its own task and
/// returns the created document URL (used by scan-and-share).
public actor DocumentProcessor {

    private let stagingFolder: URL
    private var queueTail: Task<URL?, Never>?
    private var inFlight = Set<URL>()
    /// Files the untagged processing is currently rewriting. Prevents overlapping
    /// passes (documentsChanged restart, background task) from opening or
    /// writing the same document concurrently.
    private var untaggedInFlight = Set<URL>()
    private var eventContinuations: [UUID: AsyncStream<ProcessingEvent>.Continuation] = [:]
    /// Lazily created `ContentExtractorStore`. Type-erased because Swift does
    /// not allow stored properties of an `@available(iOS 26, macOS 26)` type
    /// while the package still deploys to iOS 18 / macOS 15.
    private var contentExtractorStorage: AnyObject?

    /// - Parameter stagingFolder: Crash-safe inbox for incoming documents.
    ///   In the app this is the shared temp folder the Share Extension also
    ///   writes to.
    public init(stagingFolder: URL) {
        self.stagingFolder = stagingFolder
    }

    // MARK: - Intake

    /// Import scanned pages: persist them as JPEGs (compressed per
    /// `config.pdfQuality`), run OCR and combine them into one searchable PDF
    /// in the destination folder.
    ///
    /// - Returns: The URL of the created document, or `nil` on failure.
    @discardableResult
    public func importScan(_ pages: [CGImage], config: ProcessingConfig) async -> URL? {
        let quality = CGFloat(config.pdfQuality.rawValue)
        let imageJpegs = pages.compactMap { PlatformImage.from($0).jpg(quality: quality) }
        guard !imageJpegs.isEmpty else {
            Logger.documentProcessor.errorAndAssert("Scan import failed: could not encode any page image")
            return nil
        }

        do {
            let urls = try Staging.persist(imageJpegs: imageJpegs, in: stagingFolder)
            return await enqueue(.images(urls), config: config).value
        } catch {
            Logger.documentProcessor.errorAndAssert("Scan import failed: \(error)")
            return nil
        }
    }

    /// Import PDF data (drag & drop, file importer): persist it in the staging
    /// folder and enqueue it. Processing continues after this method returns.
    public func importPdf(_ data: Data, filename: String?, config: ProcessingConfig) {
        do {
            let url = try Staging.persist(pdfData: data, filename: filename, in: stagingFolder)
            enqueue(.pdf(url), config: config)
        } catch {
            Logger.documentProcessor.errorAndAssert("PDF import failed: \(error)")
        }
    }

    /// Enqueue everything currently in the staging folder that is not already
    /// in flight — files from the Share Extension, recovered files from an
    /// interrupted run, or files placed there by other means.
    public func processStagedFiles(config: ProcessingConfig) {
        for batch in Staging.batches(in: stagingFolder) {
            // Compare symlink-resolved paths: directory enumeration may return
            // /private/var URLs for files that were staged under /var.
            guard !batch.sourceUrls.contains(where: { inFlight.contains($0.resolvingSymlinksInPath()) }) else { continue }
            enqueue(batch, config: config)
        }
    }

    // MARK: - Untagged processing

    /// Process untagged documents where they are: add an OCR text layer to
    /// image-only PDFs (in place, dedup via the `Creator` marker) and — when
    /// `ai` is set — pre-compute AI suggestion cache entries.
    ///
    /// Runs in the caller's task so cancellation (e.g. an expiring background
    /// task) propagates into the per-page OCR checks. It does not enter the
    /// import queue: the pass and the import queue never touch the same file.
    ///
    /// - Parameters:
    ///   - documents: ALL documents of the archive. The pass filters
    ///     untagged, locally available documents itself; the tagged rest
    ///     serves as prompt context for the AI pass.
    ///   - ocr: Whether image-only PDFs should get a text layer.
    ///   - aiContext: Set to pre-compute AI suggestion cache entries.
    @discardableResult
    public func processUntaggedDocuments(in documents: [Document], config: ProcessingConfig, ocr: Bool, aiContext: AIContext?) async -> UntaggedProcessingResult {
        let untaggedDocuments = documents.filter { !$0.isTagged && $0.downloadStatus >= 1 }

        var ocrCount = 0
        if ocr {
            for document in untaggedDocuments {
                guard !Task.isCancelled else { break }

                // Skip files another (e.g. just-cancelled or background) pass
                // is still rewriting - the next documentsChanged retries them.
                let url = document.url.resolvingSymlinksInPath()
                guard !untaggedInFlight.contains(url) else { continue }
                untaggedInFlight.insert(url)
                defer { untaggedInFlight.remove(url) }

                if await Self.addOcrTextLayerIfNeeded(at: document.url, config: config) {
                    ocrCount += 1
                }
            }
            Logger.documentProcessor.info("Untagged processing: added a text layer to \(ocrCount) documents")
        }

        var aiCacheCount = 0
        if let aiContext, !Task.isCancelled, #available(iOS 26.0, macOS 26.0, *) {
            aiCacheCount = await contentExtractor.processUntaggedDocumentsInBackground(
                documents: documents,
                textExtractor: { await Self.extractText(from: $0) },
                customPrompt: aiContext.customPrompt)
            Logger.documentProcessor.info("Untagged processing: created \(aiCacheCount) AI cache entries")
        }

        return UntaggedProcessingResult(ocrCount: ocrCount, aiCacheCount: aiCacheCount)
    }

    // MARK: - Progress

    /// A stream of progress events for the import queue. Every call returns a
    /// fresh stream, so multiple observers can listen independently.
    public func events() -> AsyncStream<ProcessingEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<ProcessingEvent>.makeStream()
        continuation.onTermination = { _ in
            Task { [weak self] in
                await self?.removeEventContinuation(id)
            }
        }
        eventContinuations[id] = continuation
        return stream
    }

    private func removeEventContinuation(_ id: UUID) {
        eventContinuations[id] = nil
    }

    /// Test hook: resolves when every batch enqueued so far has been processed.
    func waitForQueue() async {
        _ = await queueTail?.value
    }

    private func emit(_ event: ProcessingEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    // MARK: - Queue

    /// Append a batch to the FIFO queue. Reads and replaces `queueTail`
    /// without suspension, so concurrent intake calls cannot interleave.
    @discardableResult
    private func enqueue(_ batch: Staging.Batch, config: ProcessingConfig) -> Task<URL?, Never> {
        for url in batch.sourceUrls {
            inFlight.insert(url.resolvingSymlinksInPath())
        }
        if let source = batch.primarySource {
            emit(.queued(source: source))
        }

        let previous = queueTail
        let task = Task(priority: .userInitiated) {
            _ = await previous?.value
            return await self.process(batch, config: config)
        }
        queueTail = task
        return task
    }

    private func process(_ batch: Staging.Batch, config: ProcessingConfig) async -> URL? {
        guard let source = batch.primarySource else { return nil }
        emit(.processing(source: source))

        let start = Date()
        do {
            let documentUrl: URL
            switch batch {
            case .images(let urls):
                documentUrl = try await Self.processImages(at: urls, config: config)

            case .pdf(let url):
                documentUrl = try await Self.processPdf(at: url, config: config)
            }

            // Delete-after-success: only now the staged originals may go away.
            for url in batch.sourceUrls {
                try? FileManager.default.removeItem(at: url)
                inFlight.remove(url.resolvingSymlinksInPath())
            }

            let timeDiff = Date().timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
            Logger.documentProcessor.info("Processing completed", metadata: ["document": "\(documentUrl.lastPathComponent)", "processing_time": "\(timeDiff)"])
            emit(.finished(source: source, document: documentUrl))
            return documentUrl
        } catch {
            // Expected for invalid input (e.g. a corrupt PDF was dropped). The
            // staged files stay in the folder AND are released from the
            // in-flight set, so a transient failure (file still being written
            // by the Share Extension, destination briefly unavailable) is
            // retried on the next processStagedFiles trigger.
            Logger.documentProcessor.error("Processing failed: \(error)")
            for url in batch.sourceUrls {
                inFlight.remove(url.resolvingSymlinksInPath())
            }
            emit(.failed(source: source, message: "\(error)"))
            return nil
        }
    }

    // MARK: - Processing core

    @concurrent
    private static func processImages(at urls: [URL], config: ProcessingConfig) async throws -> URL {
        let document = try await PDFOCREngine.createSearchablePDF(fromImagesAt: urls, marker: config.processedMarker)
        guard document.pageCount > 0 else { throw ProcessingError.noPagesRendered }

        let filename = await FilenameGenerator.filename(reusing: nil)
        let documentUrl = try uniqueDestination(for: filename, in: config.destinationFolder)
        guard document.write(to: documentUrl) else { throw ProcessingError.failedToWritePdf }
        return documentUrl
    }

    @concurrent
    private static func processPdf(at url: URL, config: ProcessingConfig) async throws -> URL {
        // Validate only - the file is moved as-is, without re-encoding it
        // through PDFKit. Text layers for image-only PDFs are added later by
        // the untagged processing.
        guard PDFDocument(url: url) != nil else { throw ProcessingError.invalidPdf }

        let filename = await FilenameGenerator.filename(reusing: url.lastPathComponent)
        let documentUrl = try uniqueDestination(for: filename, in: config.destinationFolder)
        try FileManager.default.moveItem(at: url, to: documentUrl)
        return documentUrl
    }

    /// Add an OCR text layer to the PDF at `url` if it has none yet.
    ///
    /// - Returns: `true` if OCR ran successfully and the file was updated.
    ///   `false` if the file was skipped (already had text, already marked, or
    ///   could not be opened), if OCR was cancelled, or if OCR failed.
    @concurrent
    static func addOcrTextLayerIfNeeded(at url: URL, config: ProcessingConfig) async -> Bool {
        guard let pdf = PDFDocument(url: url) else {
            Logger.ocrProcessing.debug("Could not open PDF at \(url.lastPathComponent, privacy: .public)")
            return false
        }

        guard !PDFMetadata.hasTextLayer(pdf) else { return false }
        guard !PDFMetadata.isMarked(pdf, markerPrefix: config.processedMarker) else { return false }

        Logger.ocrProcessing.info("OCR processing \(url.lastPathComponent, privacy: .public)")

        do {
            try await PDFOCREngine.addTextLayer(to: pdf, quality: config.pdfQuality)
            // A pass cancelled during OCR must not write the modified pdf -
            // a successor pass may already be reading the file.
            try Task.checkCancellation()
            if !PDFMetadata.markAsProcessed(pdf, marker: config.processedMarker, writeTo: url) {
                Logger.ocrProcessing.error("Failed to write OCR result for \(url.lastPathComponent, privacy: .public)")
                return false
            }
            Logger.ocrProcessing.info("OCR completed for \(url.lastPathComponent, privacy: .public) (\(pdf.pageCount) pages)")
            return true
        } catch is CancellationError {
            // Partially-modified `pdf` is discarded without writing, so the
            // document is retried on the next pass.
            Logger.ocrProcessing.info("OCR cancelled for \(url.lastPathComponent, privacy: .public)")
            return false
        } catch {
            Logger.ocrProcessing.error("OCR failed for \(url.lastPathComponent, privacy: .public): \(error)")
            // Mark as processed even on failure to prevent infinite retries.
            _ = PDFMetadata.markAsProcessed(pdf, marker: config.processedMarker, writeTo: url)
            return false
        }
    }

    /// Extract the text of the first pages (the same subset the tagging form
    /// uses for its suggestions).
    @concurrent
    private static func extractText(from url: URL) async -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        var content = ""
        for pageIndex in 0..<min(document.pageCount, 3) {
            guard content.count < 5000 else { break }
            content += document.page(at: pageIndex)?.string ?? ""
        }
        return content.isEmpty ? nil : content
    }

    private static func uniqueDestination(for filename: String, in folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var url = folder.appendingPathComponent(filename, isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            let base = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            let suffix = UUID().uuidString.prefix(8).lowercased()
            url = folder.appendingPathComponent("\(base)-\(suffix)" + (ext.isEmpty ? "" : ".\(ext)"), isDirectory: false)
        }
        return url
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var contentExtractor: ContentExtractorStore {
        if let store = contentExtractorStorage as? ContentExtractorStore {
            return store
        }
        let store = ContentExtractorStore()
        contentExtractorStorage = store
        return store
    }

    private enum ProcessingError: Error {
        case invalidPdf
        case noPagesRendered
        case failedToWritePdf
    }
}
