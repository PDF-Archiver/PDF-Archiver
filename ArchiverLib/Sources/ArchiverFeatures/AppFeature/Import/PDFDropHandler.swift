//
//  PDFDropHandler.swift
//  iOS
//
//  Created by Julian Kahnert on 06.06.24.
//

import Dependencies
import OSLog
import PDFKit
import Shared
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class PDFDropHandler: Log {
    @ObservationIgnored @Dependency(\.documentProcessor) var documentProcessor

    private(set) var documentProcessingState: DropButton.ButtonState = .noDocument
    var isImporting = false
    /// Number of import requests currently queued in the processor. Derived
    /// from the processor's progress events, so the button state reflects the
    /// real background queue (including staged Share Extension imports).
    private var queuedCount = 0

    init() {
        Task {
            await observeProcessingEvents()
        }
    }

    func startImport() {
        documentProcessingState = .processing
        isImporting = true
    }

    func abortImport() {
        documentProcessingState = .noDocument
        isImporting = false
    }

    func handleImport(of url: URL) async throws {
        documentProcessingState = .processing
        try await handle(input: url as any NSSecureCoding)
        await finishDropHandling()
    }

    @concurrent
    private nonisolated func handle(input item: any NSSecureCoding) async throws {
        if let data = item as? Data {
            if let pdf = PDFDocument(data: data) {
                await handle(pdf: pdf)
            } else if let image = PlatformImage(data: data) {
                await handle(image: image)
            }
        } else if let url = item as? URL {
            var pdf: PDFDocument?
            var image: PlatformImage?
            try url.securityScope { url in
                if let document = PDFDocument(url: url) {
                    pdf = document
                } else if let data = try Data(contentsOf: url) as Data?,
                          let loadedImage = PlatformImage(data: data) {
                    image = loadedImage
                } else {
                    Logger.pdfDropHandler.errorAndAssert("Could not handle url")
                }
            }
            if let pdf {
                await handle(pdf: pdf)
            } else if let image {
                await handle(image: image)
            }
        } else if let image = item as? PlatformImage {
            await handle(image: image)
        } else if let pdfDocument = item as? PDFDocument {
            await handle(pdf: pdfDocument)
        } else {
            Logger.pdfDropHandler.errorAndAssert("Failed to get data")
        }
    }

    private nonisolated func handle(image: PlatformImage) async {
        Logger.pdfDropHandler.info("Handle Image")
        _ = await documentProcessor.handleImages([image])
    }

    private nonisolated func handle(pdf: PDFDocument) async {
        Logger.pdfDropHandler.info("Handle PDF Document")
        guard let pdfData = pdf.dataRepresentation() else {
            Self.log.errorAndAssert("Could not convert PDF document to data")
            return
        }

        await documentProcessor.handlePdf(pdfData, pdf.documentURL)
    }

    private func finishDropHandling() async {
        // pick up anything that was staged but not queued (e.g. files from the
        // Share Extension)
        await documentProcessor.processStagedFiles()

        // Nothing entered the queue (e.g. the drop failed): reset the button.
        // Otherwise the progress events drive the state to .finished.
        if queuedCount == 0, documentProcessingState == .processing {
            documentProcessingState = .noDocument
        }
    }

    /// Drive the drop button from the processor's progress events.
    private func observeProcessingEvents() async {
        for await event in await documentProcessor.progressEvents() {
            switch event {
            case .queued:
                queuedCount += 1
                documentProcessingState = .processing

            case .processing:
                break

            case .finished, .failed:
                queuedCount = max(0, queuedCount - 1)
                guard queuedCount == 0 else { break }

                documentProcessingState = .finished
                try? await Task.sleep(for: .seconds(2))
                if queuedCount == 0, documentProcessingState == .finished {
                    documentProcessingState = .noDocument
                }
            }
        }
    }
}

extension PDFDropHandler: DropDelegate {
    func dropEntered(info: DropInfo) {
        documentProcessingState = .targeted
    }

    func dropExited(info: DropInfo) {
        guard documentProcessingState == .targeted else { return }
        documentProcessingState = .noDocument
    }

    func performDrop(info: DropInfo) -> Bool {
        documentProcessingState = .processing

        let types: [UTType] = [.pdf, .image, .fileURL]
        guard info.hasItemsConforming(to: types) else { return false }
        let providers = info.itemProviders(for: types)

        Task {
            do {
                for provider in providers {
                    guard let type = provider.registeredContentTypes.first else {
                        Logger.pdfDropHandler.errorAndAssert("Failed to assert")
                        continue
                    }

                    // opt out e.g. with sending to declare the reference not to be used from any other method
                    let data = try await provider.getItem(for: type)

                    guard let data else { continue }
                    if let pdf = PDFDocument(data: data) {
                        await handle(pdf: pdf)
                    } else if let image = PlatformImage(data: data) {
                        await handle(image: image)
                    }
                }
            } catch {
                Logger.pdfDropHandler.errorAndAssert("Received error \(error)")
            }
            await finishDropHandling()
        }
        return true
    }
}

extension NSItemProvider {
    func getItem(for type: UTType) async throws -> Data? {
        let item = try await loadItem(forTypeIdentifier: type.identifier)

        if let data = item as? Data {
            return data
        } else if let url = item as? URL {
            var data: Data?
            try url.securityScope { url in
                if let pdf = PDFDocument(url: url) {
                    data = pdf.dataRepresentation()
                } else if let receivedData = try Data(contentsOf: url) as Data? {
                    data = receivedData
                } else {
                    Logger.pdfDropHandler.errorAndAssert("Could not handle url")
                }
            }
            return data
        } else if let image = item as? PlatformImage {
            return image.jpg(quality: 1)
        } else if let pdfDocument = item as? PDFDocument {
            return pdfDocument.dataRepresentation()
        } else {
            Logger.pdfDropHandler.errorAndAssert("Failed to get data")
            return nil
        }
    }
}
