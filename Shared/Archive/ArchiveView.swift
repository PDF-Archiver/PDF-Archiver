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
    
    @Query(sort: \Document.date, order: .reverse) private var documents: [Document]
    
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
                Task.detached(priority: .background) {
                    await updateSuggestedTokens(from: newDocuments)
                }
            }
    }
    
    private func updateSuggestedTokens(from documents: [Document]) async {
        let mostUsedTags = documents.flatMap(\.tags).histogram
            .sorted { $0.value < $1.value }
            .reversed()
            .prefix(5)
            .map(\.key)
            .map { SearchToken.tag($0) }
        
        let possibleYears = Set(documents.map { $0.filename.prefix(4) })
        let foundYears: [SearchToken] = possibleYears
            .compactMap { Int($0) }
            .sorted()
            .reversed()
            .prefix(5)
            .map { .year($0) }
        
        guard !Task.isCancelled else { return }
        await MainActor.run {
            guard !Task.isCancelled else { return }
            suggestedTokens = mostUsedTags + foundYears
        }
    }
}

#if DEBUG
#Preview {
    ArchiveView(selectedDocumentId: .constant("debug-document-id"))
        .modelContainer(previewContainer)
}
#endif
