//
//  UntaggedDocumentsList.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 01.04.24.
//

import SwiftData
import SwiftUI

struct UntaggedDocumentsList: View {
    @Environment(NavigationModel.self) private var navigationModel
    @Query private var untaggedDocuments: [Document]

    init() {
        #warning("TODO: is this still true?")
        // we need this id because when the "last document button" was tapped, we want to show that document, too.
//        let id = navigationModel.selectedDocument?.id ?? ""
        let predicate = #Predicate<Document> { document in
//            return !document.isTagged || document.id == id
            return !document.isTagged
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\Document.date, order: .reverse)])
        descriptor.fetchLimit = 100
        self._untaggedDocuments = Query(descriptor)
    }

    var body: some View {
        @Bindable var navigationModel = navigationModel
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
}

#if DEBUG
#Preview {
    UntaggedDocumentsList()
        .modelContainer(previewContainer())
        .environment(NavigationModel())
}
#endif
