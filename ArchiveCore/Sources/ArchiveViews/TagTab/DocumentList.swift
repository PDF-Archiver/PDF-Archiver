//
//  DocumentList.swift
//  
//
//  Created by Julian Kahnert on 09.12.20.
//

import SwiftUI

struct DocumentList: View {

    @Binding var currentDocument: Document?
    @Binding var documents: [Document]
    private var taggedUntaggedDocuments: String {
        let filteredDocuments = documents.filter { $0.taggingStatus == .tagged }
        return "\(filteredDocuments.count) / \(documents.count)"
    }

    var body: some View {
        VStack {
            Text("Tagged: \(taggedUntaggedDocuments)")
                .font(Font.headline)
                .padding()
            List(documents) { document in
                HStack {
                    Circle()
                        .fill(Color.systemBlue)
                        .frame(width: 8, height: 8)
                        .opacity(document == currentDocument ? 1 : 0)
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
        DocumentList(currentDocument: $currentDocument,
                     documents: $documents)
            .previewLayout(.fixed(width: 250, height: 600))
    }
}
#endif
