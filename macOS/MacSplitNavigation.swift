//
//  MacSplitNavigation.swift
//  macOS
//
//  Created by Julian Kahnert on 28.03.24.
//

import SwiftUI

struct MacSplitNavigation: View {
    @Environment(Subscription.self) var subscription

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
        .sheet(isPresented: $tutorialShown.flipped, content: {
            OnboardingView(isPresenting: $tutorialShown.flipped)
        })
    }
}

#Preview {
    MacSplitNavigation()
}
