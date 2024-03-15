//
//  DocumentList.swift
//  
//
//  Created by Julian Kahnert on 09.12.20.
//

import SwiftUI

struct DocumentList: View {

    let shouldShowDeleteButton: Bool
    @Binding var currentDocument: Document?
    @Binding var documents: [Document]
    private var taggedUntaggedDocuments: String {
        let filteredDocuments = documents.filter { $0.taggingStatus == .tagged }
        return "\(filteredDocuments.count) / \(documents.count)"
    }

    var body: some View {
        VStack {
            HStack {
                Text("Tagged: \(taggedUntaggedDocuments)")
                    .font(Font.headline)
                    .padding()
                if shouldShowDeleteButton {
                    Button(action: {
                        guard let currentDocument = currentDocument else { return }
                        try? FileManager.default.trashItem(at: currentDocument.path, resultingItemURL: nil)
                    }, label: {
                        Label("Delete", systemImage: "trash")
                            .foregroundColor(.red)
                    })
                    .keyboardShortcut(.delete, modifiers: [.command])
                    .disabled(currentDocument == nil)
                }
            }

            // There is currently no way to remove the list separators, so we have to use a LazyVStack
            // List(documents) { document in
            ScrollView {
                LazyVStack {
                    ForEach(documents) { document in
                        HStack {
                            statusView(for: document)
                            Text(document.filename)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.currentDocument = document
                        }
                        .background((documents.firstIndex(of: document) ?? 2) % 2 == 0 ? .clear : .paSecondaryBackground)
                        .cornerRadius(5)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusView(for document: Document) -> some View {
        if document.taggingStatus == .tagged {
            Image(systemName: "checkmark.circle")
                .foregroundColor(document == currentDocument ? Color.systemBlue : Color.systemGreen)
        } else {
            Image(systemName: "circle")
                .foregroundColor(document == currentDocument ? Color.systemBlue : Color.clear)
        }
    }
}

#if DEBUG
struct DocumentList_Previews: PreviewProvider {
    static let selectedDocument = Document.create()

    @State static var currentDocument: Document? = selectedDocument
    @State static var documents = [
        Document.create(taggingStatus: .tagged),
        selectedDocument,
        Document.create(),
        Document.create()
    ]

    static var previews: some View {
        DocumentList(shouldShowDeleteButton: true,
                     currentDocument: $currentDocument,
                     documents: $documents)
            .previewLayout(.fixed(width: 250, height: 600))
    }
}
#endif
