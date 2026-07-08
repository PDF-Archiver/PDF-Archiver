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

@DependencyClient
struct DocumentProcessingDependency {
    /// Process everything that is currently staged in the temp folder (Share
    /// Extension imports, files recovered from an interrupted run).
    var processStagedFiles: @Sendable () async -> Void
    /// Import scanned pages and return the created document URL (scan-and-share).
    var handleImages: @Sendable ([PlatformImage]) async -> URL?
    /// Import PDF data (drag & drop, file importer). Returns after staging.
    var handlePdf: @Sendable (_ pdfData: Data, _ documentURL: URL?) async -> Void
    /// Runs the untagged sweep (OCR text layers + AI suggestion cache) with
    /// the current user settings.
    var processUntaggedDocuments: @Sendable (_ documents: [Document]) async -> UntaggedSweepResult = { _ in UntaggedSweepResult(ocrCount: 0, aiCacheCount: 0) }
    /// Progress events of the import queue.
    var progressEvents: @Sendable () async -> AsyncStream<ProcessingEvent> = { AsyncStream { $0.finish() } }
}

extension DocumentProcessingDependency: TestDependencyKey {
    static let previewValue = Self(
        processStagedFiles: { },
        handleImages: { _ in nil },
        handlePdf: { _, _ in },
        processUntaggedDocuments: { _ in UntaggedSweepResult(ocrCount: 0, aiCacheCount: 0) },
        progressEvents: { AsyncStream { $0.finish() } }
    )

    static let testValue = Self()
}

extension DocumentProcessingDependency: DependencyKey {
    private static let documentProcessor = DocumentProcessor(stagingFolder: Constants.tempDocumentURL)

    /// One-time migration: move working copies that a pre-pipeline app version
    /// left in the legacy `processing/` subfolder back into the staging folder,
    /// so they are imported again.
    private static let legacyProcessingFolderMigration: Void = {
        let legacyFolder = Constants.tempDocumentURL.appendingPathComponent("processing")
        guard let urls = try? FileManager.default.contentsOfDirectory(at: legacyFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else { return }

        for url in urls {
            var destination = Constants.tempDocumentURL.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                destination = Constants.tempDocumentURL.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            }
            do {
                try FileManager.default.moveItem(at: url, to: destination)
                Logger.app.info("Recovered legacy processing file \(url.lastPathComponent, privacy: .public)")
            } catch {
                Logger.app.error("Failed to recover legacy processing file: \(error)")
            }
        }
        try? FileManager.default.removeItem(at: legacyFolder)
    }()

    /// Resolve the per-request pipeline config from the current user settings.
    private static func makeConfig() async throws -> ProcessingConfig {
        @Shared(.pdfQuality) var pdfQuality: PDFQuality
        let destinationFolder = try await ArchiveStore.shared.getUntaggedUrl()
        return ProcessingConfig(destinationFolder: destinationFolder,
                                pdfQuality: pdfQuality,
                                processedMarker: "PDF Archiver")
    }

    static let liveValue = DocumentProcessingDependency(
        processStagedFiles: {
            _ = legacyProcessingFolderMigration
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
                let pages = images.compactMap(\.cgImage)
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

            let ai: AIContext? = (appleIntelligenceEnabled && cacheEnabled) ? AIContext(customPrompt: customPrompt) : nil
            guard ocrEnabled || ai != nil else { return UntaggedSweepResult(ocrCount: 0, aiCacheCount: 0) }

            do {
                let config = try await makeConfig()
                return await documentProcessor.processUntaggedDocuments(in: documents, config: config, ocr: ocrEnabled, ai: ai)
            } catch {
                Logger.app.error("Untagged sweep failed to resolve the untagged folder: \(error)")
                return UntaggedSweepResult(ocrCount: 0, aiCacheCount: 0)
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
