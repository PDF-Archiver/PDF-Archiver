//
//  UntaggedDocumentsList.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 01.04.24.
//

import SwiftData
import SwiftUI

struct UntaggedDocumentsList: View {
    static let untaggedDocumentSortOrder = [SortDescriptor(\Document.filename, order: .forward), SortDescriptor(\Document.id)]
    @Environment(NavigationModel.self) private var navigationModel
    @Query private var untaggedDocuments: [Document]

    init() {
        let predicate = #Predicate<Document> { document in
            return !document.isTagged
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: Self.untaggedDocumentSortOrder)
        descriptor.fetchLimit = 100
        self._untaggedDocuments = Query(descriptor)
    }

    var body: some View {
        @Bindable var navigationModel = navigationModel
        Group {
            if untaggedDocuments.isEmpty {
                ContentUnavailableView("No document", systemImage: "checkmark.seal", description: Text("Congratulations! All documents are tagged. 🎉"))
            } else {
                List(untaggedDocuments, selection: $navigationModel.selectedDocument) { document in
                    NavigationLink(document.filename, value: document)
                }
                .listStyle(.plain)
                #if os(macOS)
                .alternatingRowBackgrounds()
                #endif
            }
        }
        .navigationTitle("Untagged Documents")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#if DEBUG
#Preview {
    UntaggedDocumentsList()
        .modelContainer(previewContainer())
        .environment(NavigationModel.shared)
}
#endif
