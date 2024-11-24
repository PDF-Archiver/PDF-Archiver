//
//  MacSplitNavigation.swift
//  macOS
//
//  Created by Julian Kahnert on 28.03.24.
//

import SwiftUI
import OSLog

struct MacSplitNavigation: View {
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(Subscription.self) var subscription

    @State private var dropHandler = PDFDropHandler()
    @AppStorage("tutorialShown", store: .appGroup) private var tutorialShown = false
    
    var body: some View {
        NavigationSplitView {
            Group {
                if navigationModel.untaggedMode {
                    UntaggedDocumentsList()
                } else {
                    ArchiveView()
                }
            }
            .modifier(ArchiveStoreLoading())
            .frame(minWidth: 300)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        navigationModel.switchToUntaggedMode()
                    } label: {
                        Label(navigationModel.untaggedMode ? "Tagging Mode" : "Archive Mode", systemImage: navigationModel.untaggedMode ? "tag.fill" : "archivebox.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        } detail: {
            if navigationModel.untaggedMode {
                UntaggedDocumentView()
                    .sheet(isPresented: subscription.isSubscribed, content: {
                        InAppPurchaseView(onCancel: {
                            navigationModel.switchToUntaggedMode()
                        })
                    })
            } else {
                DocumentDetailView()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            DropButton(state: dropHandler.documentProcessingState, action: {
                dropHandler.startImport()
            })
            .padding(.bottom, 16)
            .padding(.trailing, 16)
            .opacity(navigationModel.untaggedMode ? 0 : 1)
        }
        .sheet(isPresented: $tutorialShown.flipped) {
            OnboardingView(isPresenting: $tutorialShown.flipped)
                .frame(width: 500, height: 400)
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
}

#if DEBUG
#Preview {
    MacSplitNavigation()
}
#endif
