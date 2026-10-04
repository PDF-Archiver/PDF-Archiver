//
//  ScanButtonModifier.swift
//  
//
//  Created by Julian Kahnert on 09.08.25.
//

import ArchiverModels
import Dependencies
import Logging
import Shared
import SwiftUI
import TipKit

struct ScanButtonModifier: ViewModifier {
    let showButton: Bool
    let currentTip: (any Tip)?
    var isShowingDocument = false

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
            #if os(macOS)
            .toolbar {
                if !isShowingDocument {
                    ToolbarItem(placement: .primaryAction) {
                        ImportToolbarButton(state: dropHandler.documentProcessingState) {
                            dropHandler.startImport()
                        }
                        .popoverTip((showButton && (currentTip as? ScanShareTip) != nil) ? currentTip : nil) { _ in
                            dropHandler.startImport()
                        }
                        .tipImageSize(.init(width: 24, height: 24))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.tint, lineWidth: 3)
                    .background(.tint.opacity(0.08), in: .rect(cornerRadius: 12))
                    .padding(4)
                    .opacity(dropHandler.documentProcessingState == .targeted ? 1 : 0)
                    .animation(.snappy, value: dropHandler.documentProcessingState)
                    .allowsHitTesting(false)
            }
            #else
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                DropButton(state: dropHandler.documentProcessingState) { shouldShare in
                    shouldShareAfterScan = shouldShare
                    isScanPresented = true
                }
                .padding(.trailing, 10)
                .opacity(showButton ? 1 : 0)
                .popoverTip((showButton && (currentTip as? ScanShareTip) != nil) ? currentTip : nil) { tipAction in
                    shouldShareAfterScan = (tipAction.id == "scanAndShare")
                    isScanPresented = true
                }
                .tipImageSize(.init(width: 24, height: 24))
                .matchedTransitionSource(id: "scanButton", in: scanButtonNamespace)
            }
            .sheet(isPresented: $isScanPresented) {
                DocumentCameraView(
                    isShown: $isScanPresented,
                    imageHandler: { images in
                        Task {
                            await feedbackGenerator.notify(.success)

                            // Handle images and get the processed document URL
                            let processedDocumentUrl = await documentProcessor.handleImages(images)

                            // Share the scanned document when it was requested
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
            .task {
                await dropHandler.observeProcessingEvents()
            }
            .fileImporter(isPresented: $dropHandler.isImporting, allowedContentTypes: [.pdf, .image]) { result in
                Task {
                    do {
                        let url = try result.get()
                        try await dropHandler.handleImport(of: url)
                        } catch {
                            Logger.pdfDropHandler.error("Failed to import file", metadata: ["error": "\(LogRedact.describe(error))"])
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
            .onOpenURL { url in
                switch url {
                case DeepLink.scan.url:
                    isScanPresented = true

                case DeepLink.scanAndShare.url:
                    isScanPresented = true
                    shouldShareAfterScan = true

                default:
                    break
                }
            }
    }
}

#if os(macOS)
/// The Mac counterpart of `DropButton`: imports through the file browser and shows the drop progress.
private struct ImportToolbarButton: View {
    let state: DropButton.ButtonState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text("Import Document", bundle: #bundle)
            } icon: {
                ZStack {
                    Image(systemName: "square.and.arrow.down")
                        .opacity(![.processing, .finished].contains(state) ? 1 : 0)

                    ProgressView()
                        .controlSize(.small)
                        .opacity(state == .processing ? 1 : 0)

                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                        .opacity(state == .finished ? 1 : 0)
                }
            }
        }
        .help(Text("Import Document", bundle: #bundle))
        .keyboardShortcut("i", modifiers: [.command, .shift])
    }
}

#Preview("ImportToolbarButton") {
    HStack {
        ImportToolbarButton(state: .noDocument) {}
        ImportToolbarButton(state: .processing) {}
        ImportToolbarButton(state: .finished) {}
    }
    .padding()
}
#endif
