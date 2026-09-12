//
//  DocumentProcessingDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import DocumentProcessingPipeline
import Foundation
import OSLog
import Shared
#if canImport(UIKit)
import UIKit
#endif

@DependencyClient
struct DocumentProcessingDependency {
    /// Process everything that is currently staged in the temp folder (Share
    /// Extension imports, files recovered from an interrupted run).
    var processStagedFiles: @Sendable () async -> Void
    /// Import scanned pages and return the created document URL (scan-and-share).
    var handleImages: @Sendable ([PlatformImage]) async -> URL?
    /// Import PDF data (drag & drop, file importer). Returns after staging.
    var handlePdf: @Sendable (_ pdfData: Data, _ documentURL: URL?) async -> Void
    /// Runs the untagged processing (OCR text layers + AI suggestion cache) with
    /// the current user settings.
    var processUntaggedDocuments: @Sendable (_ documents: [Document]) async -> UntaggedProcessingResult = { _ in UntaggedProcessingResult(ocrCount: 0, aiCacheCount: 0) }
    /// Re-runs OCR on one document, whether or not it already has a text layer.
    /// Independent of `ocrEnabled`, which only gates the automatic sweep.
    var runOcr: @Sendable (_ url: URL) async -> Bool = { _ in false }
    /// Progress events of the import queue.
    var progressEvents: @Sendable () async -> AsyncStream<ProcessingEvent> = { AsyncStream { $0.finish() } }
}

extension DocumentProcessingDependency: TestDependencyKey {
    static let previewValue = Self(
        processStagedFiles: { },
        handleImages: { _ in nil },
        handlePdf: { _, _ in },
        processUntaggedDocuments: { _ in UntaggedProcessingResult(ocrCount: 0, aiCacheCount: 0) },
        runOcr: { _ in false },
        progressEvents: { AsyncStream { $0.finish() } }
    )

    static let testValue = Self()
}

extension DocumentProcessingDependency: DependencyKey {
    private static let documentProcessor = DocumentProcessor(stagingFolder: Constants.tempDocumentURL)

    /// Resolve the per-request pipeline config from the current user settings.
    private static func makeConfig() async throws -> ProcessingConfig {
        @Shared(.pdfQuality) var pdfQuality: PDFQuality
        let destinationFolder = try await ArchiveStore.shared.getUntaggedUrl()
        return ProcessingConfig(destinationFolder: destinationFolder,
                                pdfQuality: pdfQuality,
                                processedMarker: "PDF Archiver",
                                ocrEngineVersion: 2)
    }

    static let liveValue = DocumentProcessingDependency(
        processStagedFiles: {
            do {
                let config = try await makeConfig()
                await documentProcessor.processStagedFiles(config: config)
            } catch {
                Logger.app.error("Staged file processing failed to resolve the untagged folder: \(error)")
            }
        },
        handleImages: { images in
            do {
                let config = try await makeConfig()
                // Normalize the orientation first: `cgImage` returns the raw
                // bitmap and would drop the EXIF rotation of camera images.
                let pages = images.compactMap { $0.normalizedOrientation().cgImage }
                return await documentProcessor.importScan(pages, config: config)
            } catch {
                Logger.app.error("Scan import failed to resolve the untagged folder: \(error)")
                return nil
            }
        },
        handlePdf: { pdfData, documentURL in
            do {
                let config = try await makeConfig()
                await documentProcessor.importPdf(pdfData, filename: documentURL?.lastPathComponent, config: config)
            } catch {
                Logger.app.error("PDF import failed to resolve the untagged folder: \(error)")
            }
        },
        processUntaggedDocuments: { documents in
            @Shared(.ocrEnabled) var ocrEnabled: Bool
            @Shared(.appleIntelligenceEnabled) var appleIntelligenceEnabled: Bool
            @Shared(.appleIntelligenceCacheEnabled) var cacheEnabled: Bool
            @Shared(.appleIntelligenceCustomPrompt) var customPrompt: String?

            let aiContext: AIContext? = (appleIntelligenceEnabled && cacheEnabled) ? AIContext(customPrompt: customPrompt) : nil
            guard ocrEnabled || aiContext != nil else { return UntaggedProcessingResult(ocrCount: 0, aiCacheCount: 0) }

            do {
                let config = try await makeConfig()
                return await documentProcessor.processUntaggedDocuments(in: documents, config: config, ocr: ocrEnabled, aiContext: aiContext)
            } catch {
                Logger.app.error("Untagged processing failed to resolve the untagged folder: \(error)")
                return UntaggedProcessingResult(ocrCount: 0, aiCacheCount: 0)
            }
        },
        runOcr: { url in
            do {
                let config = try await makeConfig()
                return await documentProcessor.runOcrTextLayer(at: url, config: config)
            } catch {
                Logger.app.error("Manual OCR failed to resolve the untagged folder: \(error)")
                return false
            }
        },
        progressEvents: {
            await documentProcessor.events()
        }
    )
}

extension DependencyValues {
    var documentProcessor: DocumentProcessingDependency {
        get { self[DocumentProcessingDependency.self] }
        set { self[DocumentProcessingDependency.self] = newValue }
    }
}

extension PlatformImage {
    /// Bake the EXIF orientation into the bitmap so `cgImage` matches what
    /// the user saw. NSImage has no orientation concept, so this is a no-op
    /// on macOS.
    fileprivate func normalizedOrientation() -> PlatformImage {
        #if canImport(UIKit)
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        #else
        return self
        #endif
    }
}
