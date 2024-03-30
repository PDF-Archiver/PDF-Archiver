//
//  MacSplitNavigation.swift
//  macOS
//
//  Created by Julian Kahnert on 28.03.24.
//

import SwiftUI

struct MacSplitNavigation: View {
    @State var selectedDocumentId: String?

    var body: some View {
        NavigationSplitView {
            NewArchiveView(selectedDocumentId: $selectedDocumentId)
        } detail: {
            NewDocumentDetailView(documentId: $selectedDocumentId)
        }
    }
}

#Preview {
    MacSplitNavigation()
}
