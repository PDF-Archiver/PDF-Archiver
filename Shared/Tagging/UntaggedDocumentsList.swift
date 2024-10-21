//
//  UntaggedDocumentsList.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 01.04.24.
//

import SwiftData
import SwiftUI

#warning("TODO: improve document list design")
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
        .onChange(of: selectedDocumentId) { _, currentDocumentId in
            guard currentDocumentId == nil,
                  let firstDocument = untaggedDocuments.first else { return }

            #warning("TODO: fix this")
            // ATTENTION: changing the selected document here will/might result in undefined behaviour!
            // The navigation flows will be corrupted (e.g. navigation not possible anymore).
//            selectedDocumentId = firstDocument.id
        }
    }
}

#if DEBUG
#Preview {
    UntaggedDocumentsList(selectedDocumentId: .constant(nil))
        .modelContainer(previewContainer())
}
#endif
