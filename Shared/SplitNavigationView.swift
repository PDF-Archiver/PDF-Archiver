//
//  SplitNavigationView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 25.11.24.
//

import SwiftUI
import OSLog

struct SplitNavigationView: View {
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.modelContext) private var modelContext

    @State private var dropHandler = PDFDropHandler()
    @AppStorage("tutorialShown", store: .appGroup) private var tutorialShown = false

    var body: some View {
        NavigationSplitView {
            Group {
                switch navigationModel.mode {
                case .archive:
                    ArchiveView()
                case .tagging:
                    UntaggedDocumentsList()
                }
            }
            .modifier(ArchiveStoreLoading())
            .frame(minWidth: 300)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        navigationModel.switchTaggingMode(in: modelContext)
                    } label: {
                        Label(navigationModel.mode == .archive ? "Archive Mode" : "Tagging Mode", systemImage: navigationModel.mode == .archive ? "archivebox" : "tag")
                    }
                }
                #if !os(macOS)
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button {
                            navigationModel.showScan()
                        } label: {
                            Label("Scan", systemImage: "doc.viewfinder")
                                .labelStyle(.titleAndIcon)
                        }
                        Button {
                            navigationModel.showPreferences()
                        } label: {
                            Label("Preferences", systemImage: "gear")
                                .labelStyle(.titleAndIcon)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                #endif
            }
        } detail: {
            switch navigationModel.mode {
            case .archive:
                DocumentDetailView()
            case .tagging:
                UntaggedDocumentView()
//                    #if !DEBUG
                    .sheet(isPresented: navigationModel.isSubscribed) {
                        InAppPurchaseView() {
                            navigationModel.switchTaggingMode(in: modelContext)
                        }
                    }
//                    #endif
            }
        }
        .modifier(AlertDataModelProvider())
        .overlay(alignment: .bottomTrailing) {
            DropButton(state: dropHandler.documentProcessingState, action: {
                #if os(macOS)
                dropHandler.startImport()
                #else
                navigationModel.showScan()
                #endif
            })
            .padding(4)
            .background(Color.paPlaceholderGray)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 16)
            .padding(.trailing, 16)
            .opacity(navigationModel.mode == .archive ? 1 : 0)
        }
        .sheet(isPresented: $tutorialShown.flipped) {
            OnboardingView(isPresenting: $tutorialShown.flipped)
                #if os(macOS)
                .frame(width: 500, height: 400)
                #endif
        }
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
        .task {
            _ = await DocumentProcessingService.shared

        }
    }

    @State var alert: Alert?
}

#if DEBUG
#Preview {
    SplitNavigationView()
}
#endif
