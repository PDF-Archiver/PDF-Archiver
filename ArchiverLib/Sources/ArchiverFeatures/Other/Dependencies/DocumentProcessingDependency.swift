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
import Foundation
import Shared

@DependencyClient
struct DocumentProcessingDependency {
    var triggerFolderObservation: @Sendable () async -> Void
    var handleImages: @Sendable ([PlatformImage]) async -> Void
    var handlePdf: @Sendable (_ pdfData: Data, _ documentURL: URL?) async -> Void
}

extension DocumentProcessingDependency: TestDependencyKey {
    static let previewValue = Self(
        triggerFolderObservation: { },
        handleImages: { _ in },
        handlePdf: { _, _ in },
    )

    static let testValue = Self()
}

extension DocumentProcessingDependency: DependencyKey {
    @StorageActor
    private static var _documentProcessingService: DocumentProcessingService?

    @StorageActor
    private static func getDocumentProcessingService() async -> DocumentProcessingService {
        if let service = _documentProcessingService {
            return service
        }

        let service = DocumentProcessingService(tempDocumentURL: Constants.tempDocumentURL,
                                                documentDestination: {
            try await ArchiveStore.shared.getUntaggedUrl()
        })
        _documentProcessingService = service

        return service
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
    )
}

extension DependencyValues {
    var documentProcessor: DocumentProcessingDependency {
        get { self[DocumentProcessingDependency.self] }
        set { self[DocumentProcessingDependency.self] = newValue }
    }
}
