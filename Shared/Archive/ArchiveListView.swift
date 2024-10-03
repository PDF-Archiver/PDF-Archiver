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
    @Query private var documents: [Document]
    
    @Binding private var selectedDocumentId: String?
    @Binding private var shoudLoadAll: Bool
    private let searchString: String

    init(selectedDocumentId: Binding<String?>, shoudLoadAll: Binding<Bool>, searchString: String, descriptor: FetchDescriptor<Document>) {
        self.searchString = searchString
        self._selectedDocumentId = selectedDocumentId
        self._shoudLoadAll = shoudLoadAll

        _documents = Query(descriptor)
    }

    var body: some View {
        if documents.isEmpty {
            #warning("TODO: show appropriate message when no documents were found because of the search string")
            ContentUnavailableView("Empty Archive", systemImage: "archivebox", description: Text("Start scanning and tagging your first document."))
        } else {
            content
        }
    }

private var content: some View {
    List(selection: $selectedDocumentId) {
        ForEach(documents) { document in
            ArchiveListItemView(document: document)
                .frame(maxWidth: .infinity, maxHeight: 65.0)
        }

        if searchString.isEmpty {
            HStack {
                Spacer()
                Button(action: {
                    shoudLoadAll.toggle()
                }, label: {
                    #warning("TODO: visualize which mode is active")
                    Label("Load remaining documents", systemImage: "arrow.down.circle")
                })
                .padding(6)
                Spacer()
            }
        }
    }
    .listStyle(.plain)
    #if os(macOS)
    .alternatingRowBackgrounds()
    #endif
}

    private func status(for document: Document) -> some View {
        VStack {
            Image(systemName: "icloud.and.arrow.down")
            Text(document.size.converted(to: .bytes).formatted(.byteCount(style: .file)))
                .font(.caption)
        }
        .foregroundColor(.gray)
    }
}

#Preview {
    ArchiveListView(selectedDocumentId: .constant(nil), shoudLoadAll: .constant(false), searchString: "", descriptor: FetchDescriptor<Document>())
}
