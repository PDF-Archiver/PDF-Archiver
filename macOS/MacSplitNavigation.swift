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
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        untaggedMode.toggle()
                    } label: {
                        Label("Archive Mode", systemImage: untaggedMode ? "tag.slash.fill" : "tag.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        } detail: {
            if untaggedMode {
                UntaggedDocumentView(documentId: $selectedDocumentId)
            } else {
                NewDocumentDetailView(documentId: $selectedDocumentId)
            }
        }
    }
}

#Preview {
    MacSplitNavigation()
}
