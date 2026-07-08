//
//  DocumentProcessingDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverDocumentProcessing
import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import DocumentProcessingPipeline
import Foundation
import OSLog
import Shared

@DependencyClient
struct DocumentProcessingDependency {
    var triggerFolderObservation: @Sendable () async -> Void
    var handleImages: @Sendable ([PlatformImage]) async -> URL?
    var handlePdf: @Sendable (_ pdfData: Data, _ documentURL: URL?) async -> Void
    var getLastProcessedDocumentUrl: @Sendable () async -> URL?
    /// Runs the untagged sweep (OCR text layers + AI suggestion cache) with
    /// the current user settings.
    var processUntaggedDocuments: @Sendable (_ documents: [Document]) async -> UntaggedSweepResult = { _ in UntaggedSweepResult(ocrCount: 0, aiCacheCount: 0) }
}

extension DocumentProcessingDependency: TestDependencyKey {
    static let previewValue = Self(
        triggerFolderObservation: { },
        handleImages: { _ in nil },
        handlePdf: { _, _ in },
        getLastProcessedDocumentUrl: { nil },
        processUntaggedDocuments: { _ in UntaggedSweepResult(ocrCount: 0, aiCacheCount: 0) }
    )

    static let testValue = Self()
}

extension DocumentProcessingDependency: DependencyKey {
    @MainActor
    private static var _documentProcessingService: DocumentProcessingService?

    @MainActor
    private static func getDocumentProcessingService() async -> DocumentProcessingService {
        if let service = _documentProcessingService {
            return service
        }

        let service = await DocumentProcessingService(tempDocumentURL: Constants.tempDocumentURL,
                                                documentDestination: {
            try await ArchiveStore.shared.getUntaggedUrl()
        })
        _documentProcessingService = service

        return service
    }

    private static let documentProcessor = DocumentProcessor(stagingFolder: Constants.tempDocumentURL)

    /// Resolve the per-request pipeline config from the current user settings.
    private static func makeConfig() async throws -> ProcessingConfig {
        @Shared(.pdfQuality) var pdfQuality: PDFQuality
        let destinationFolder = try await ArchiveStore.shared.getUntaggedUrl()
        return ProcessingConfig(destinationFolder: destinationFolder,
                                pdfQuality: pdfQuality,
                                processedMarker: "PDF Archiver")
    }

    static let liveValue = DocumentProcessingDependency(
        triggerFolderObservation: {
            await getDocumentProcessingService().triggerObservation()
        },
        handleImages: { images in
            await getDocumentProcessingService().handle(images)
        },
        handlePdf: { pdfData, documentURL in
            await getDocumentProcessingService().handle(pdfData, url: documentURL)
        },
        getLastProcessedDocumentUrl: {
            await getDocumentProcessingService().lastProcessedDocumentUrl
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
        }
    )
}

extension DependencyValues {
    var documentProcessor: DocumentProcessingDependency {
        get { self[DocumentProcessingDependency.self] }
        set { self[DocumentProcessingDependency.self] = newValue }
    }
}
