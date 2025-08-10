//
//  ScanButtonModifier.swift
//  
//
//  Created by Julian Kahnert on 09.08.25.
//

import OSLog
import Shared
import SwiftUI
import TipKit

struct ScanButtonModifier: ViewModifier {
    let showButton: Bool
    let currentTip: (any Tip)?

    @Namespace var scanButtonNamespace
    @State private var dropHandler = PDFDropHandler()
    @State private var isScanPresented = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                DropButton(state: dropHandler.documentProcessingState) { _ in
                    #warning("TODO: add this")
//                    #if os(macOS)
//                    dropHandler.startImport()
//                    #else
//                    navigationModel.showScan(share: isLongPress)
//                    #endif
                }
                .padding(.bottom, 16)
                .padding(.trailing, 16)
                .opacity(showButton ? 1 : 0)
                .popoverTip((showButton && (currentTip as? ScanShareTip) != nil) ? currentTip : nil) { _ in
                    #warning("TODO: add this")
//                    #if os(macOS)
//                    dropHandler.startImport()
//                    #else
//                    navigationModel.showScan(share: tipAction.id == "scanAndShare")
//                    #endif
                }
                .tipImageSize(.init(width: 24, height: 24))
                .matchedTransitionSource(id: "scanButton", in: scanButtonNamespace)
            }
            #if !os(macOS)
            .sheet(isPresented: $isScanPresented) {
                DocumentCameraView(
                    isShown: $isScanPresented,
                    imageHandler: { _ in
                        #warning("TODO: add this")
//                        Task {
//                            await FeedbackGenerator.notify(.success)
//                            await DocumentProcessingService.shared.handle(images)
//                        }
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
                            #warning("TODO: add this")
//                            NotificationCenter.default.postAlert(error)
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
