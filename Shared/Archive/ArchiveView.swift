//
//  ArchiveView.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import SwiftUI
import SwiftData

struct ArchiveView: View {
    
    // TODO: remove this after fetching suggsted tokens on a background thread
    init(selectedDocumentId: Binding<String?>) {
        self._selectedDocumentId = selectedDocumentId
        
        var descriptor = FetchDescriptor<Document>.init()
        descriptor.fetchLimit = 50
        _documents = Query(descriptor)
    }
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    #warning("TODO: should we exclude the pdf content to reduce memory size here?")
    @Query(sort: \Document.date, order: .reverse) private var documents: [Document]
    
    @Binding var selectedDocumentId: String?
    @State private var searchText = ""
    @State private var tokens: [SearchToken] = []
    @State private var suggestedTokens: [SearchToken] = [.year(2024), .year(2023), .year(2022), .tag("arzt")]
    
    @State private var shoudLoadAll = false
    
    var body: some View {
        content
            .searchable(text: $searchText, tokens: $tokens, suggestedTokens: $suggestedTokens, placement: .toolbar, prompt: "Search your documents", token: { token in
                switch token {
                case .term(let term):
                    Label("\(term)", systemImage: "text.magnifyingglass")
                case .tag(let tag):
                    Label("\(tag)", systemImage: "tag")
                case .year(let year):
                    Label(Self.formatter.string(from: year as NSNumber) ?? "", systemImage: "calendar")
                }
            })
            .onChange(of: documents) { _, newDocuments in
                // TODO: also fetch documents on a background thread
                print("DEBUGGING: on change is called")
                Task.detached(priority: .background) {
                    let mostUsedTags = newDocuments.flatMap(\.tags).histogram
                        .sorted { $0.value < $1.value }
                        .reversed()
                        .prefix(5)
                        .map(\.key)
                        .map { SearchToken.tag($0) }
                    
                    let possibleYears = Set(newDocuments.map { $0.filename.prefix(4) })
                    let foundYears: [SearchToken] = possibleYears
                        .compactMap { Int($0) }
                        .sorted()
                        .reversed()
                        .prefix(5)
                        .map { .year($0) }
                    
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        self.suggestedTokens = mostUsedTags + foundYears
                    }
                }
            }
            .navigationTitle("Archive")
    }
    
    @ViewBuilder
    private var content: some View {
        if documents.isEmpty {
            ContentUnavailableView("Empty Archive", systemImage: "archivebox", description: Text("Start scanning and tagging your first document."))
        } else {
            ArchiveListView(selectedDocumentId: $selectedDocumentId,
                            shoudLoadAll: $shoudLoadAll,
                            searchString: searchText,
                            descriptor: updateQuery())
        }
    }
    
    private func updateQuery() -> FetchDescriptor<Document> {
        
        var predicate: Predicate<Document>?
//        if let termToken = tokens.first(where: { $0.isTerm }) {
//            let term = termToken.term
//            predicate = #Predicate { document in
//                return document.isTagged && document.specification.contains(term) || document.tags.contains(term)
//            }
//        } else if let yearToken = tokens.first(where: { $0.isYear }) {
//            let term = yearToken.term
//            predicate = #Predicate { document in
//                return document.isTagged && document.filename.starts(with: term)
//            }
//        } else {
//            predicate = #Predicate { document in
//                return document.isTagged
//            }
//        }

        let searchString = self.searchText
        
        let taggedDocumentPredicate = #Predicate<Document> { document in
            document.isTagged
        }
        
        let searchTermPredicate = #Predicate<Document> { document in
            searchString.isEmpty ? true : document.filename.contains(searchString)
        }
        
        let yearPredicate = #Predicate<Document> { document in
            // TODO: implement year filter
//            document.filename.starts(with: "2024")
            true
        }
        
        // TODO: implement tag filter
        
        predicate = #Predicate { document in
            return taggedDocumentPredicate.evaluate(document) && searchTermPredicate.evaluate(document) && yearPredicate.evaluate(document)
        }
        
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\Document.date, order: .reverse)])

        let shouldNotLimit = shoudLoadAll && searchString.isEmpty
        descriptor.fetchLimit = shouldNotLimit ? nil : 50
        
        return descriptor

    }
}
