//
//  DeleteDocumentButtonView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 25.10.24.
//

import SwiftUI

struct DeleteDocumentButtonView: View {
    let documentUrl: URL?
    let action: (URL) -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label(String(localized: "Delete", bundle: #bundle), systemImage: "trash")
                .foregroundColor(documentUrl == nil ? Color.gray : .red)
        }
        .disabled(documentUrl == nil)
        .labelStyle(.iconOnly)
        .confirmationDialog(String(localized: "Do you really want to delete this document?", bundle: #bundle),
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button(String(localized: "Delete", bundle: #bundle), role: .destructive) {
                guard let documentUrl else {
                    assertionFailure("No document selected")
                    return
                }

                action(documentUrl)
            }
            Button(String(localized: "Cancel", bundle: #bundle), role: .cancel) {
                withAnimation {
                    showDeleteConfirmation = false
                }
            }
        }
    }
}
