//
//  ArchiveListView.swift
//  iOS
//
//  Created by Julian Kahnert on 19.03.24.
//

import SwiftData
import SwiftUI
import OSLog

struct ArchiveListView: View {
    @Environment(NavigationModel.self) private var navigationModel
    @Query private var documents: [Document]

    @Binding private var shoudLoadAll: Bool
    private let searchString: String

    init(shoudLoadAll: Binding<Bool>, searchString: String, descriptor: FetchDescriptor<Document>) {
        self.searchString = searchString
        self._shoudLoadAll = shoudLoadAll

        _documents = Query(descriptor)
    }

    var body: some View {
        @Bindable var navigationModel = navigationModel
        if documents.isEmpty {
            if !searchString.isEmpty {
                ContentUnavailableView("No document found", systemImage: "magnifyingglass", description: Text("Try another search query."))
            } else {
                ContentUnavailableView("Empty Archive", systemImage: "archivebox", description: Text("Start scanning and tagging your first document."))
            }
        } else {
            List(selection: $navigationModel.selectedDocument) {
                ForEach(documents) { document in
                    NavigationLink(value: document) {
                        ArchiveListItemView(document: document)
                    }
                }

                if searchString.isEmpty {
                    Button {
                        shoudLoadAll.toggle()
                    } label: {
                        Label(shoudLoadAll ? "Load less documents" : "Load all documents", systemImage: shoudLoadAll ? "arrow.up.circle" : "arrow.down.circle")
                    }
                }
            }
            .listStyle(.plain)
            #if os(macOS)
            .alternatingRowBackgrounds()
            #endif
        }
}

}

#Preview {
    ArchiveListView(shoudLoadAll: .constant(false), searchString: "", descriptor: FetchDescriptor<Document>())
}
