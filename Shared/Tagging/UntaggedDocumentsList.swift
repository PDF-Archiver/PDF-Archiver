//
//  UntaggedDocumentsList.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 01.04.24.
//

import SwiftData
import SwiftUI

struct UntaggedDocumentsList: View {
    @Query private var untaggedDocuments: [Document]
    @Binding var selectedDocumentId: String?

    init(selectedDocumentId: Binding<String?>) {
        // we need this id because when the "last document button" was tapped, we want to show that document, too.
        let id = selectedDocumentId.wrappedValue ?? ""
        let predicate = #Predicate<Document> { document in
            return !document.isTagged || document.id == id
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\Document.date, order: .reverse)])
        descriptor.fetchLimit = 100
        self._untaggedDocuments = Query(descriptor)
        self._selectedDocumentId = selectedDocumentId
    }

    var body: some View {
        if untaggedDocuments.isEmpty {
            ContentUnavailableView("No document", systemImage: "checkmark.seal", description: Text("Congratulations! All documents are tagged. 🎉"))
        } else {
            List(selection: $selectedDocumentId) {
                ForEach(untaggedDocuments) { document in
                    Text(document.filename)
                        .lineLimit(1)
                }
            }
            .listStyle(.plain)
            #if os(macOS)
            .alternatingRowBackgrounds()
            #endif
        }
    }
}

#if DEBUG
#Preview {
    UntaggedDocumentsList(selectedDocumentId: .constant(nil))
        .modelContainer(previewContainer())
}
#endif
