//
//  ArchiveListView.swift
//  iOS
//
//  Created by Julian Kahnert on 19.03.24.
//

import SwiftData
import SwiftUI

struct ArchiveListView: View {
    @Query private var documents: [DBDocument]
    @Binding var selectedDocumentId: String?

    let tokens: [SearchToken]

    init(selectedDocumentId: Binding<String?>, searchString: String, tokens: [SearchToken]) {
        var predicate: Predicate<DBDocument>?
        if let termToken = tokens.first(where: { $0.isTerm }) {
            let term = termToken.term
            predicate = #Predicate { document in
                return document.isTagged && document.specification.contains(term) || document.tags.contains(term)
            }
        } else if let yearToken = tokens.first(where: { $0.isYear }) {
            let term = yearToken.term
            predicate = #Predicate { document in
                return document.isTagged && document.filename.starts(with: term)
            }
        } else {
            predicate = #Predicate { document in
                return document.isTagged
            }
        }
        
        if searchString.isEmpty {
            self.tokens = tokens
        } else {
            self.tokens = [.term(searchString)] + tokens
        }
        _documents = Query(filter: predicate, sort: [SortDescriptor(\DBDocument.date, order: .reverse)])
        _selectedDocumentId = selectedDocumentId
    }
    
    var filteredDocuments: [DBDocument] {
        documents.filter { document in
            tokens.allSatisfy { token in
                switch token {
                case .term(let term):
                    return document.specification.contains(term)
                case .tag(let tag):
                    return document.tags.contains(tag)
                case .year(let year):
                    return document.filename.starts(with: "\(year)")
                }
            }
        }
    }
    
    var body: some View {
        List(selection: $selectedDocumentId) {
            ForEach(filteredDocuments) { document in
                NavigationLink(value: document.id) {
                    VStack(alignment: .leading, spacing: 4.0) {
                        Text(document.specification)
                            .font(.headline)
                        Text(document.date, format: .dateTime.year().month().day())
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        TagListView(tags: .constant(document.tags.sorted()), isEditable: false, isMultiLine: false, tapHandler: nil)
                            .font(.caption)
                        //                    HStack {
                        //                        if showTagStatus {
                        //                            Text(viewModel.taggingStatus == .tagged ? "✅" : " ")
                        //                        }
                        //                        titleSubtitle
                        //                            .layoutPriority(2)
                        //                        Spacer()
                        //                        status
                        //                            .fixedSize()
                        //                            .layoutPriority(1)
                        //                            .opacity((!showTagStatus && viewModel.downloadStatus.isRemote) ? 1 : 0)
                        //                    }
                        //                    .layoutPriority(1)
                        
                        ProgressView(value: document.downloadStatus, total: 1)
                            .progressViewStyle(.linear)
                            .foregroundColor(.paDarkGray)
                            .frame(maxHeight: 4)
                            .opacity((document.downloadStatus == 0 || document.downloadStatus == 1) ? 0 : 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 65.0)
                }
            }
        }
        .listRowSeparator(.hidden)
    }
}

#Preview {
    ArchiveListView(selectedDocumentId: .constant(nil), searchString: "test", tokens: [])
}
