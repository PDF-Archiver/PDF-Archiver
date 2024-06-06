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
    
    func handleImport(of url: URL) throws {
        try handle(url: url)
        finishDropHandling()
    }
    
    private func handle(url: URL) throws {
        documentProcessingState = .processing
        try url.securityScope { url in
            if let pdf = PDFDocument(url: url) {
                handle(pdf: pdf)
                return
            }
            
            let data = try Data(contentsOf: url)
            if let image = Image(data: data) {
                handle(image: image)
            } else {
                Logger.pdfDropHandler.errorAndAssert("Could not handle url")
            }
        }
    }
    
    private func handle(image: Image) {
        Logger.pdfDropHandler.info("Handle Image")
        
        let documentName = "PDF-Archiver-\(Date().timeIntervalSinceReferenceDate).jpeg"
        let imageDestinationUrl = PathConstants.tempPdfURL.appendingPathComponent(documentName, isDirectory: false)
        
        guard let jpegData = image.jpg(quality: 1) else {
            Logger.pdfDropHandler.errorAndAssert("Failed to get jpeg data")
            return
        }
        
        do {
            try jpegData.write(to: imageDestinationUrl)
        } catch {
            Logger.pdfDropHandler.errorAndAssert("Failed to write jpeg", metadata: ["error": "\(error)"])
        }
    }
    
    private func handle(pdf: PDFDocument) {
        Logger.pdfDropHandler.info("Handle PDF Document")
        
        let documentName = pdf.documentURL?.lastPathComponent ?? "PDF-Archiver-\(Date().timeIntervalSinceReferenceDate).pdf"
        let pdfDestinationUrl = PathConstants.tempPdfURL.appendingPathComponent(documentName, isDirectory: false)
        
        let pdfWritten = pdf.write(to: pdfDestinationUrl)
        if !pdfWritten {
            Logger.pdfDropHandler.errorAndAssert("Failed to write pdf")
        }
    }
    
    private func finishDropHandling() {
        guard documentProcessingState != .noDocument else { return }
        
        let wasProcessing = documentProcessingState == .processing
        documentProcessingState = wasProcessing ? .finished : .noDocument
        
        guard wasProcessing else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.documentProcessingState = .noDocument
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
            defer {
                finishDropHandling()
            }
            do {
                for provider in providers {
                    guard let type = provider.registeredContentTypes.first else {
                        Logger.pdfDropHandler.errorAndAssert("Failed to assert")
                        continue
                    }

                    let item = try await provider.loadItem(forTypeIdentifier: type.identifier)
                    if let data = item as? Data {
                        if let pdf = PDFDocument(data: data) {
                            handle(pdf: pdf)
                        } else if let image = Image(data: data) {
                            handle(image: image)
                        }
                        
                    } else if let url = item as? URL {
                        try handle(url: url)
                        
                    } else if let image = item as? Image {
                        handle(image: image)
                        
                    } else if let pdfDocument = item as? PDFDocument {
                        handle(pdf: pdfDocument)
                        
                    } else {
                        Logger.pdfDropHandler.errorAndAssert("Failed to get data")
                    }
                }
            } catch {
                Logger.pdfDropHandler.errorAndAssert("Received error \(error)")
            }
        }
        return true
    }
}
