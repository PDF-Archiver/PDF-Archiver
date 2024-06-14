//
//  PDFDropHandler.swift
//  iOS
//
//  Created by Julian Kahnert on 06.06.24.
//

import OSLog
#if os(macOS)
import AppKit.NSImage
private typealias Image = NSImage
#else
import UIKit.UIImage
private typealias Image = UIImage
#endif

import UniformTypeIdentifiers
import SwiftUI
import PDFKit

@Observable
final class PDFDropHandler {
    private(set) var documentProcessingState: DropButton.State = .noDocument
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
    private func handle(image: Image) {
        Logger.pdfDropHandler.info("Handle Image")
        
        guard let jpegData = image.jpg(quality: 1),
            let ciImage = CIImage(data: jpegData) else {
            Logger.pdfDropHandler.errorAndAssert("Failed to get jpeg data")
            return
        }
        
        do {
            try StorageHelper.save([ciImage])
        } catch {
            Logger.pdfDropHandler.errorAndAssert("Failed to write jpeg", metadata: ["error": "\(error)"])
        }
    }
    
    @StorageActor
    private func handle(pdf: PDFDocument) {
        Logger.pdfDropHandler.info("Handle PDF Document")
        
        let documentName = pdf.documentURL?.lastPathComponent ?? "PDF-Archiver-\(Date().timeIntervalSinceReferenceDate).pdf"
        let pdfDestinationUrl = PathConstants.tempDocumentURL.appendingPathComponent(documentName, isDirectory: false)
        
        let pdfWritten = pdf.write(to: pdfDestinationUrl)
        if !pdfWritten {
            Logger.pdfDropHandler.errorAndAssert("Failed to write pdf")
        }
    }
    
    private func finishDropHandling() async {
        guard documentProcessingState != .noDocument else { return }
        
        let wasProcessing = documentProcessingState == .processing
        documentProcessingState = wasProcessing ? .finished : .noDocument
        
        guard wasProcessing else { return }
        await DocumentProcessingService.shared.triggerFolderObservation()
        
        try? await Task.sleep(for: .seconds(2))
        
#warning("TODO: test if the sleep works")
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

                    let item = try await provider.loadItem(forTypeIdentifier: type.identifier)
                    try await handle(input: item)
                }
            } catch {
                Logger.pdfDropHandler.errorAndAssert("Received error \(error)")
            }
            await finishDropHandling()
        }
        return true
    }
}
