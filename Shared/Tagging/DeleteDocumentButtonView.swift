//
//  DeleteDocumentButtonView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 25.10.24.
//

import SwiftUI

struct DeleteDocumentButtonView: View {
    let action: () -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        Button("Delete", systemImage: "trash") {
            showDeleteConfirmation = true

        }
        .labelStyle(.iconOnly)
        .confirmationDialog("Do you really want to delete this document?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                action()
            }
            Button("Cancel", role: .cancel) {
                withAnimation {
                    showDeleteConfirmation = false
                }
            }
        }
    }
}
