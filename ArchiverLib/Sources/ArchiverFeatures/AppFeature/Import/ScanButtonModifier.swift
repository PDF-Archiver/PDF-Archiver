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
    @Namespace var scanButtonNamespace
    @State private var dropHandler = PDFDropHandler()
    @State private var isScanPresented = false

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                DropButton(state: dropHandler.documentProcessingState) { _ in
                    #if os(macOS)
                    dropHandler.startImport()
                    #else
                    #warning("TODO: handle long press")
                    isScanPresented = true
                    #endif
                }
                #if os(macOS)
                .padding(.bottom, 16)
                #endif
                .padding(.trailing, 12)
                .opacity(showButton ? 1 : 0)
                .popoverTip((showButton && (currentTip as? ScanShareTip) != nil) ? currentTip : nil) { _ in
                    #if os(macOS)
                    dropHandler.startImport()
                    #else
                    #warning("TODO: handle long press")
//                    navigationModel.showScan(share: tipAction.id == "scanAndShare")
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
                            #warning("TODO: add this as a separate dependency")
//                            await FeedbackGenerator.notify(.success)
                            await documentProcessor.handleImages(images)

                            await Task.yield()
                            await AfterFirstImportTip.documentImported.donate()
                        }
                    })
                    .edgesIgnoringSafeArea(.all)
                    .statusBar(hidden: true)
                    .navigationTransition(.zoom(sourceID: "scanButton", in: scanButtonNamespace))
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
