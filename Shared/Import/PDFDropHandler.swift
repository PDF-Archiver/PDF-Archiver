//
//  PDFDropHandler.swift
//  iOS
//
//  Created by Julian Kahnert on 06.06.24.
//

#if os(macOS)
import AppKit.NSImage
private typealias Image = NSImage
#else
import UIKit.UIImage
private typealias Image = UIImage
#endif

import OSLog
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class PDFDropHandler: Log {
    private(set) var documentProcessingState: DropButton.ButtonState = .noDocument
    var isImporting = false

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

    @StorageActor
    private func handle(input item: any NSSecureCoding) async throws {
        if let data = item as? Data {
            if let pdf = PDFDocument(data: data) {
                handle(pdf: pdf)
            } else if let image = Image(data: data) {
                handle(image: image)
            }

        } else if let url = item as? URL {
            try url.securityScope { url in
                if let pdf = PDFDocument(url: url) {
                    handle(pdf: pdf)
                    return
                } else if let data = try Data(contentsOf: url) as Data?,
                          let image = Image(data: data) {
                    handle(image: image)
                } else {
                    Logger.pdfDropHandler.errorAndAssert("Could not handle url")
                }
            }

        } else if let image = item as? Image {
            handle(image: image)

        } else if let pdfDocument = item as? PDFDocument {
            handle(pdf: pdfDocument)

        } else {
            Logger.pdfDropHandler.errorAndAssert("Failed to get data")
        }
    }

    @StorageActor
    private func handle(image: PlatformImage) {
        Logger.pdfDropHandler.info("Handle Image")
        Task {
            await DocumentProcessingService.shared.handle([image])
        }
    }

    @StorageActor
    private func handle(pdf: PDFDocument) {
        Logger.pdfDropHandler.info("Handle PDF Document")
        Task {
            guard let pdfData = pdf.dataRepresentation() else {
                Self.log.errorAndAssert("Could not convert PDF document to data")
                return
            }

            await DocumentProcessingService.shared.handle(pdfData, url: pdf.documentURL)
        }
    }

    private func finishDropHandling() async {
        guard documentProcessingState != .noDocument else { return }

        let wasProcessing = documentProcessingState == .processing
        documentProcessingState = wasProcessing ? .finished : .noDocument

        guard wasProcessing else { return }
        await DocumentProcessingService.shared.triggerFolderObservation()

        try? await Task.sleep(for: .seconds(2))

        self.documentProcessingState = .noDocument
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
                    } else if let image = Image(data: data) {
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

        } else if let image = item as? Image {
            return image.jpg(quality: 1)

        } else if let pdfDocument = item as? PDFDocument {
            return pdfDocument.dataRepresentation()

        } else {
            Logger.pdfDropHandler.errorAndAssert("Failed to get data")
            return nil
        }
    }
}
