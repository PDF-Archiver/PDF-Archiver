//
//  MacSplitNavigation.swift
//  macOS
//
//  Created by Julian Kahnert on 28.03.24.
//

import SwiftUI
import OSLog

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
                dropHandler.startImport()
            })
            .padding(.bottom, 4)
            .padding(.trailing, 4)
        })
        .sheet(isPresented: $tutorialShown.flipped, content: {
            OnboardingView(isPresenting: $tutorialShown.flipped)
        })
        .onDrop(of: [.image, .pdf, .fileURL],
                delegate: dropHandler)
        .fileImporter(isPresented: $dropHandler.isImporting,
                      allowedContentTypes: [.pdf, .image]) { result in
            do {
                let url = try result.get()
                try dropHandler.handleImport(of: url)
            } catch {
                Logger.pdfDropHandler.errorAndAssert("Failed to get imported url", metadata: ["error": "\(error)"])
                NotificationCenter.default.postAlert(error)
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

#if DEBUG
#Preview {
    MacSplitNavigation()
}
#endif
