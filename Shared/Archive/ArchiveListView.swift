//
//  ArchiveListView.swift
//  iOS
//
//  Created by Julian Kahnert on 19.03.24.
//

import SwiftData
import SwiftUI

struct ArchiveListView: View {
    @Query private var documents: [Document]
    @Binding var selectedDocumentId: String?
    @Binding var shoudLoadAll: Bool

    let tokens: [SearchToken]
    let searchString: String

    init(selectedDocumentId: Binding<String?>, searchString: String, tokens: [SearchToken], shoudLoadAll: Binding<Bool>) {
        self._shoudLoadAll = shoudLoadAll
        self.searchString = searchString
        var predicate: Predicate<Document>?
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
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\Document.date, order: .reverse)])
        if !(shoudLoadAll.wrappedValue || !searchString.isEmpty) {
            descriptor.fetchLimit = 50
        }
        _documents = Query(descriptor)
        _selectedDocumentId = selectedDocumentId
    }
    
    private var filteredDocuments: [Document] {
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
                VStack(alignment: .leading, spacing: 4.0) {
                    Text(document.specification)
                        .font(.headline)
                    Text(document.date, format: .dateTime.year().month().day())
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    
                    TagListView(tags: document.tags.sorted(), isEditable: false, isMultiLine: false, tapHandler: nil)
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
            
            #if os(macOS)
            if !(shoudLoadAll || !searchString.isEmpty) {
                HStack {
                    Spacer()
                    Button(action: {
                        shoudLoadAll.toggle()
                    }, label: {
                        Label("Load remaining documents", systemImage: "arrow.down.circle")
                    })
                    Spacer()
                }
            }
            #endif
        }
        .listStyle(.plain)
        #if os(macOS)
        .alternatingRowBackgrounds()
        #else
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    shoudLoadAll.toggle()
                }, label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Load remaining documents")
                    }
                })
                .disabled(shoudLoadAll == true)
            }
        }
        #endif
    }
}

#Preview {
    ArchiveListView(selectedDocumentId: .constant(nil), searchString: "test", tokens: [], shoudLoadAll: .constant(false))
}
