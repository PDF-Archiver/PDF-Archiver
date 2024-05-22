//
//  MacSplitNavigation.swift
//  macOS
//
//  Created by Julian Kahnert on 28.03.24.
//

import SwiftUI

struct MacSplitNavigation: View {
    @State private var selectedDocumentId: String?
    @AppStorage("taggingMode") private var untaggedMode = false

    var body: some View {
        NavigationSplitView {
            Group {
                if untaggedMode {
                    UntaggedDocumentsList(selectedDocumentId: $selectedDocumentId)
                } else {
                    NewArchiveView(selectedDocumentId: $selectedDocumentId)
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
            } else {
                DocumentDetailView(documentId: $selectedDocumentId, untaggedMode: $untaggedMode)
            }
        }
    }
}

#Preview {
    MacSplitNavigation()
}
