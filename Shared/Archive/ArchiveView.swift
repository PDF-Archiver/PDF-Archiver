//
//  ArchiveView.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import SwiftUI
import SwiftData

struct ArchiveView: View {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    @Query private var tags: [Tag]
    
    @Binding var selectedDocumentId: String?
    @State private var searchText = ""
    @State private var tokens: [SearchToken] = []
    @State private var suggestedTokens: [SearchToken] = [.year(2024), .year(2023), .year(2022), .tag("arzt")]
    
    @State private var shoudLoadAll = false
    
    var body: some View {
        ArchiveListView(selectedDocumentId: $selectedDocumentId,
                        shoudLoadAll: $shoudLoadAll,
                        searchString: searchText,
                        descriptor: updateQuery())
        .searchable(text: $searchText, tokens: $tokens, suggestedTokens: $suggestedTokens, placement: .toolbar, prompt: "Search your documents", token: { token in
            switch token {
            case .tag(let tag):
                Label("\(tag)", systemImage: "tag")
            case .year(let year):
                Label(Self.formatter.string(from: year as NSNumber) ?? "", systemImage: "calendar")
            }
        })
        .onChange(of: tags) { _, newDocuments in
            
            // ideally the tags should be filtered + sorted via a fetch descriptor,
            //                var descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.documents.count, order: .forward)])
            //                descriptor.fetchLimit = 5
            //                _tags = Query(descriptor)
            
            let mostUsedTags = tags
                .sorted(by: { $0.documents.count < $1.documents.count })
                .reversed()
                .prefix(5)
                .map { SearchToken.tag($0.name) }
            
            let currentYear = Calendar.current.component(.year, from: Date())
            let mostRecentYears: [SearchToken] = [.year(currentYear),
                                                  .year(currentYear - 1),
                                                  .year(currentYear - 2),
                                                  .year(currentYear - 3),
                                                  .year(currentYear - 4)]
            
            self.suggestedTokens = mostUsedTags + mostRecentYears
        }
        .navigationTitle("Archive")
    }
    
    private func updateQuery() -> FetchDescriptor<Document> {
        
        assert(tokens.count <= 1, "Too many tokens: \(tokens)")
        let token = tokens.first
        let searchString = self.searchText
        
        var predicate: Predicate<Document>?
        
        // only find tagged documents
        let taggedDocumentPredicate = #Predicate<Document> { document in
            document.isTagged
        }
        
        // filter by search term
        let searchTermPredicate = #Predicate<Document> { document in
            searchString.isEmpty ? true : document.filename.localizedStandardContains(searchString)
        }
        
        // filter by token
        let tokenPredicate: Predicate<Document>
        if let token {
            switch token {
            case .tag(let tag):
                tokenPredicate = #Predicate<Document> { document in
                    document.tagItems.contains(where: { $0.name == tag })
                }
            case .year(let year):
                tokenPredicate = #Predicate<Document> { document in
                    document.filename.starts(with: "\(year)")
                }
            }
        } else {
            tokenPredicate = #Predicate<Document> { _ in true }
        }
        predicate = #Predicate { document in
            return taggedDocumentPredicate.evaluate(document) && searchTermPredicate.evaluate(document) && tokenPredicate.evaluate(document)
        }
        
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\Document.date, order: .reverse)])
        let shouldNotLimit = shoudLoadAll && searchString.isEmpty
        descriptor.fetchLimit = shouldNotLimit ? nil : 50
        
        return descriptor
    }
}
