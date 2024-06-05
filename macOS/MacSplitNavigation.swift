//
//  MacSplitNavigation.swift
//  macOS
//
//  Created by Julian Kahnert on 28.03.24.
//

import UniformTypeIdentifiers
import SwiftUI

struct MacSplitNavigation: View {
    @Environment(Subscription.self) var subscription

    @State private var dropHandler = PDFDropHandler()
    @State private var selectedDocumentId: String?
    @AppStorage("taggingMode", store: .appGroup) private var untaggedMode = false
    @AppStorage("tutorialShown", store: .appGroup) private var tutorialShown = false

    var body: some View {
        NavigationSplitView {
            Group {
                if untaggedMode {
                    UntaggedDocumentsList(selectedDocumentId: $selectedDocumentId)
                } else {
                    ArchiveView(selectedDocumentId: $selectedDocumentId)
                }
            }
            .frame(minWidth: 300)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        untaggedMode.toggle()
                        selectedDocumentId = nil
                    } label: {
                        Label(untaggedMode ? "Tagging Mode" : "Archive Mode", systemImage: untaggedMode ? "tag.fill" : "archivebox.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        } detail: {
            if untaggedMode {
                UntaggedDocumentView(documentId: $selectedDocumentId)
                    .sheet(isPresented: subscription.isSubscribed, content: {
                        InAppPurchaseView(onCancel: {
                            untaggedMode = false
                        })
                    })
            } else {
                DocumentDetailView(documentId: $selectedDocumentId, untaggedMode: $untaggedMode)
            }
        }
        .overlay(alignment: .bottomTrailing, content: {
            DropButton(state: dropHandler.documentProcessingState, action: {
                #warning("TODO: opening file here")
                print("Openeing file")
            })
            .padding(.bottom, 4)
            .padding(.trailing, 4)
        })
        .sheet(isPresented: $tutorialShown.flipped, content: {
            OnboardingView(isPresenting: $tutorialShown.flipped)
        })
        .onDrop(of: [.image, .pdf, .fileURL],
                delegate: dropHandler)
    }
}

import OSLog
#if os(macOS)
import AppKit.NSImage
private typealias Image = NSImage
#else
import UIKit.UIImage
private typealias Image = UIImage
#endif

import PDFKit

@Observable
final class PDFDropHandler: DropDelegate {
    private(set) var documentProcessingState: DropButton.State = .noDocument
//    private(set) var isDropTarget = false
    func dropEntered(info: DropInfo) {
//        isDropTarget = true
        documentProcessingState = .targeted
    }
    
    func dropExited(info: DropInfo) {
//        isDropTarget = false
        documentProcessingState = .noDocument
//        guard oldValue != newValue,
//              documentProcessingState == .noDocument || documentProcessingState == .targeted else { return }
//        
//        documentProcessingState = newValue ? .targeted : .noDocument
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
                    if let data = item as? Data {
                        if let pdf = PDFDocument(data: data) {
                            Self.handle(pdf: pdf)
                        } else if let image = Image(data: data) {
                            Self.handle(image: image)
                        }
                        
                    } else if let url = item as? URL {
                        if let pdf = PDFDocument(url: url) {
                            Self.handle(pdf: pdf)
                        } else if let data = try? Data(contentsOf: url),
                                  let image = Image(data: data) {
                            Self.handle(image: image)
                        }
                        
                    } else if let image = item as? Image {
                        Self.handle(image: image)
                        
                    } else if let pdfDocument = item as? PDFDocument {
                        Self.handle(pdf: pdfDocument)
                        
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
    
    private static func handle(image: Image) {
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
    
    private static func handle(pdf: PDFDocument) {
        Logger.pdfDropHandler.info("Handle PDF Document")
        
        let documentName = pdf.documentURL?.lastPathComponent ?? "PDF-Archiver-\(Date().timeIntervalSinceReferenceDate).pdf"
        let pdfDestinationUrl = PathConstants.tempPdfURL.appendingPathComponent(documentName, isDirectory: false)
        
        let pdfWritten = pdf.write(to: pdfDestinationUrl)
        if !pdfWritten {
            Logger.pdfDropHandler.errorAndAssert("Failed to write pdf")
        }
    }
}

#if DEBUG
#Preview {
    MacSplitNavigation()
}
#endif
