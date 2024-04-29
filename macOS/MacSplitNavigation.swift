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
            VStack {
                Toggle(isOn: $untaggedMode, label: {
                    Text("Show untagged")
                })
                .toggleStyle(SwitchToggleStyle())
                
                if untaggedMode {
                    UntaggedDocumentsList(selectedDocumentId: $selectedDocumentId)
                } else {
                    NewArchiveView(selectedDocumentId: $selectedDocumentId)
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
