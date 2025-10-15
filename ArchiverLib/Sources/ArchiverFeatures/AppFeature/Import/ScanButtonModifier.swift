//
//  ScanButtonModifier.swift
//  
//
//  Created by Julian Kahnert on 09.08.25.
//

import Dependencies
import OSLog
import Shared
import SwiftUI
import TipKit

struct ScanButtonModifier: ViewModifier {
    let showButton: Bool
    let currentTip: (any Tip)?

    @Dependency(\.documentProcessor) var documentProcessor
    @Dependency(\.feedbackGenerator) var feedbackGenerator
    @Namespace var scanButtonNamespace
    @State private var dropHandler = PDFDropHandler()
    @State private var isScanPresented = false
    @State private var shouldShareAfterScan = false
    @State private var isShareSheetPresented = false
    @State private var documentToShare: URL?

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                DropButton(state: dropHandler.documentProcessingState) { isLongPress in
                    #if os(macOS)
                    dropHandler.startImport()
                    #else
                    shouldShareAfterScan = isLongPress
                    isScanPresented = true
                    #endif
                }
                #if os(macOS)
                .padding(.bottom, 24)
                .padding(.trailing, 40)
                #else
                .padding(.trailing, 10)
                #endif
                .opacity(showButton ? 1 : 0)
                .popoverTip((showButton && (currentTip as? ScanShareTip) != nil) ? currentTip : nil) { tipAction in
                    #if os(macOS)
                    dropHandler.startImport()
                    #else
                    shouldShareAfterScan = (tipAction.id == "scanAndShare")
                    isScanPresented = true
                    #endif
                }
                .tipImageSize(.init(width: 24, height: 24))
                .matchedTransitionSource(id: "scanButton", in: scanButtonNamespace)
            }
            #if !os(macOS)
            .sheet(isPresented: $isScanPresented) {
                DocumentCameraView(
                    isShown: $isScanPresented,
                    imageHandler: { images in
                        Task {
                            await feedbackGenerator.notify(.success)

                            // Handle images and get the processed document URL
                            let processedDocumentUrl = await documentProcessor.handleImages(images)

                            // If long press was used, share the scanned document
                            if let url = processedDocumentUrl {
                                await MainActor.run {
                                    if shouldShareAfterScan {
                                        documentToShare = url
                                        isShareSheetPresented = true
                                        shouldShareAfterScan = false
                                    }
                                }
                            } else {
                                await MainActor.run {
                                    shouldShareAfterScan = false
                                }
                            }
                            
                            await AfterFirstImportTip.documentImported.donate()
                        }
                    })
                    .edgesIgnoringSafeArea(.all)
                    .statusBar(hidden: true)
                    .navigationTransition(.zoom(sourceID: "scanButton", in: scanButtonNamespace))
            }
            .sheet(isPresented: $isShareSheetPresented) {
                if let url = documentToShare {
                    ShareSheet(title: url.lastPathComponent, url: url)
                }
            }
            #endif
            .onDrop(of: [.image, .pdf, .fileURL],
                    delegate: dropHandler)
            .fileImporter(isPresented: $dropHandler.isImporting, allowedContentTypes: [.pdf, .image]) { result in
                Task {
                    do {
                        let url = try result.get()
                        try await dropHandler.handleImport(of: url)
                        } catch {
                            Logger.pdfDropHandler.errorAndAssert("Failed to get imported url", metadata: ["error": "\(error)"])
                            NotificationCenter.default.postAlert(error)
                        }
                }
            }
            .onChange(of: dropHandler.isImporting) { oldValue, newValue in
                // special case: abort importing
                guard oldValue,
                      !newValue,
                      dropHandler.documentProcessingState == .processing else { return }

                dropHandler.abortImport()
            }
    }
}
