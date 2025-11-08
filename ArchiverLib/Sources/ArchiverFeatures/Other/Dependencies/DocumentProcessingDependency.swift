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
import OSLog
import PDFKit
import Shared

@DependencyClient
struct DocumentProcessingDependency {
    var triggerFolderObservation: @Sendable () async -> Void
    var handleImages: @Sendable ([PlatformImage]) async -> URL?
    var handlePdf: @Sendable (_ pdfData: Data, _ documentURL: URL?) async -> Void
    var getLastProcessedDocumentUrl: @Sendable () async -> URL?
    var handleDropProviders: @Sendable ([NSItemProvider]) async -> Void
    var handleFileImportUrl: @Sendable (URL) async throws -> Void
}

extension DocumentProcessingDependency: TestDependencyKey {
    static let previewValue = Self(
        triggerFolderObservation: { },
        handleImages: { _ in nil },
        handlePdf: { _, _ in },
        getLastProcessedDocumentUrl: { nil },
        handleDropProviders: { _ in },
        handleFileImportUrl: { _ in }
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
        handleDropProviders: { providers in
            let service = await getDocumentProcessingService()
            for provider in providers {
                guard let type = provider.registeredContentTypes.first else {
                    Logger.pdfDropHandler.errorAndAssert("Failed to get content type")
                    continue
                }

                do {
                    let item = try await provider.loadItem(forTypeIdentifier: type.identifier)

                    if let data = item as? Data {
                        if let pdf = PDFDocument(data: data) {
                            if let pdfData = pdf.dataRepresentation() {
                                await service.handle(pdfData, url: nil)
                            }
                        } else if let image = PlatformImage(data: data) {
                            _ = await service.handle([image])
                        }
                    } else if let url = item as? URL {
                        var data: Data?
                        url.securityScope { url in
                            if let pdf = PDFDocument(url: url) {
                                data = pdf.dataRepresentation()
                            } else if let receivedData = try? Data(contentsOf: url) {
                                data = receivedData
                            } else {
                                Logger.pdfDropHandler.errorAndAssert("Could not handle url")
                            }
                        }
                        if let data {
                            if let pdf = PDFDocument(data: data) {
                                if let pdfData = pdf.dataRepresentation() {
                                    await service.handle(pdfData, url: nil)
                                }
                            } else if let image = PlatformImage(data: data) {
                                _ = await service.handle([image])
                            }
                        }
                    } else if let image = item as? PlatformImage {
                        _ = await service.handle([image])
                    } else if let pdfDocument = item as? PDFDocument {
                        if let pdfData = pdfDocument.dataRepresentation() {
                            await service.handle(pdfData, url: nil)
                        }
                    }
                } catch {
                    Logger.pdfDropHandler.errorAndAssert("Received error \(error)")
                }
            }
        },
        handleFileImportUrl: { url in
            let service = await getDocumentProcessingService()
            var pdfData: Data?
            var imageData: Data?

            // Synchronous security scope to read file data
            try url.securityScope { url in
                if let pdf = PDFDocument(url: url) {
                    pdfData = pdf.dataRepresentation()
                    imageData = nil
                } else {
                    pdfData = nil
                    imageData = try? Data(contentsOf: url)
                }
            }

            // Async processing outside security scope
            if let pdfData {
                await service.handle(pdfData, url: url)
            } else if let imageData, let image = PlatformImage(data: imageData) {
                _ = await service.handle([image])
            } else {
                Logger.pdfDropHandler.errorAndAssert("Could not handle url")
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
