//
//  NewArchiveView.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import SwiftUI
import SwiftData

struct NewArchiveView: View {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    @Query(sort: \DBDocument.date, order: .reverse) private var documents: [DBDocument]
    
    @Binding var selectedDocumentId: String?
    @State private var searchText = ""
    @State private var tokens: [SearchToken] = []
    @State private var suggestedTokens: [SearchToken] = [.year(2024), .year(2023), .year(2022)]
    
    @State private var shoudLoadAll = false
    
    var body: some View {
        ArchiveListView(selectedDocumentId: $selectedDocumentId, searchString: searchText, tokens: tokens, shoudLoadAll: $shoudLoadAll)
            .searchable(text: $searchText, tokens: $tokens, suggestedTokens: $suggestedTokens, placement: .toolbar, prompt: "Search in documents", token: { token in
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
                
                suggestedTokens = mostUsedTags + foundYears
            }
    }
}

#Preview {
    NewArchiveView(selectedDocumentId: .constant("debug-document-id"))
        .modelContainer(previewContainer)
}
