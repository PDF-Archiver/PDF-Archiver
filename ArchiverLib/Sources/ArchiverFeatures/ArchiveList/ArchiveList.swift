//
//  ArchiveList.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 03.07.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI

@Reducer
struct ArchiveList {
    @ObservableState
    struct State: Equatable {
        enum SearchToken: Hashable, Identifiable, Sendable {
            case tag(String)
            case year(Int)
            case text(String)

            var id: String { description }

            var description: String {
                switch self {
                case .tag(let tag):
                    "tag: \(tag)"
                case .year(let year):
                    "year: \(year)"
                case .text(let text):
                    "text: \(text)"
                }
            }

            var value: String {
                switch self {
                case .tag(let tag):
                    return tag
                case .year(let year):
                    return "\(year)"
                case .text(let text):
                    return text
                }
            }
        }

        @Shared(.documents) var documents: IdentifiedArrayOf<Document> = []
        @Shared(.selectedDocumentId) var selectedDocumentId: Int?
        var filteredDocuments: IdentifiedArrayOf<Document> { getFilteredDocument() }
        var isSearching = false
        var searchText = ""
        var searchTokens: [SearchToken] = []
        // fallback until real suggestions are derived from the documents in AppFeature
        var searchSuggestedTokens: [SearchToken] = {
            let currentYear = Calendar.current.component(.year, from: Date())
            return [.year(currentYear), .year(currentYear - 1)]
        }()
        @Presents var documentDetails: DocumentDetails.State?

        private func getFilteredDocument() -> IdentifiedArrayOf<Document> {
            // Pre-compute slugified search text once instead of per document
            let normalizedSearchText = searchText.isEmpty ? nil : searchText.slugified(withSeparator: "-")
            return documents
                .filter { document in
                    guard document.isTagged else { return false }

                    for searchToken in searchTokens {
                        switch searchToken {
                        case .tag(let tag):
                            guard document.tags.contains(tag) else { return false }
                        case .year(let int):
                            guard document.url.lastPathComponent.hasPrefix("\(int)") else { return false }
                        case .text(let text):
                            guard document.url.lastPathComponent.localizedCaseInsensitiveContains(text) else { return false }
                        }
                    }

                    if let normalizedSearchText {
                        return document.url.lastPathComponent.localizedCaseInsensitiveContains(normalizedSearchText)
                    }
                    return true
                }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case selectionChanged(Int?)
        case documentDetails(PresentationAction<DocumentDetails.Action>)
        case searchStateChanged(Bool)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .documentDetails:
                return .none

            case .searchStateChanged(let isSearching):
                state.isSearching = isSearching
                return .none

            case .selectionChanged(let documentId):
                state.$selectedDocumentId.withLock { $0 = documentId }
                if let documentId,
                   let document = Shared(state.$documents[id: documentId]) {
                    state.documentDetails = .init(document: document)
                } else {
                    state.documentDetails = nil
                }
                return .none
            case .binding(\.searchText):
                var searchText = state.searchText
                if searchText.popLast() == " " {
                    let newSearchText = searchText.slugified(withSeparator: "").lowercased()

                    // an empty token would filter out all documents
                    if !newSearchText.isEmpty {
                        state.searchTokens.append(.text(newSearchText))
                    }
                    state.searchText = ""
                }
                return .none
            case .binding:
                return .none
            }
        }
        .ifLet(\.$documentDetails, action: \.documentDetails) {
            DocumentDetails()
        }
    }
}

struct ArchiveListView: View {
    @Bindable var store: StoreOf<ArchiveList>

    var body: some View {
        // request filtered documents only once in this render cylce
        let filteredDocuments = store.filteredDocuments
        Group {
            if filteredDocuments.isEmpty {
                if store.searchText.isEmpty {
                    ContentUnavailableView(String(localized: "Empty Archive", bundle: #bundle),
                                           systemImage: "archivebox",
                                           description: Text("Start scanning and tagging your first document.", bundle: #bundle))
                    // fix the alignment of the ScanButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let text = store.searchTokens.map({ "'\($0.value)' " }).joined() + store.searchText
                    ContentUnavailableView.search(text: text)
                        // fix the alignment of the ScanButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List(filteredDocuments, selection: Binding(get: { store.selectedDocumentId }, set: { store.send(.selectionChanged($0)) })) { document in
                    ArchiveListItemView(documentSpecification: document.specification,
                                        documentDate: document.date,
                                        documentTags: document.tags.sorted())
                    .tag(document.id)
                }
            }
        }
        .modifier(SearchStateMonitor { _, newValue in
            store.send(.searchStateChanged(newValue))
        })
        .searchable(text: $store.searchText,
                    tokens: $store.searchTokens,
                    suggestedTokens: $store.searchSuggestedTokens,
//                    placement: .toolbar,
                    prompt: String(localized: "Search your documents", bundle: #bundle)) { token in
            switch token {
            case .tag(let tag):
                Label(tag, systemImage: "tag")
            case .year(let year):
                Label("\(year, format: .number.grouping(.never))", systemImage: "calendar")
            case .text(let text):
                Label(text, systemImage: "text.viewfinder")
            }
        }
        .sensoryFeedback(.selection, trigger: store.selectedDocumentId)
        .navigationDestination(item: $store.scope(\.$documentDetails, action: \.documentDetails)) { documentStore in
            DocumentDetailsView(store: documentStore)
                .navigationTitle(documentStore.document.specification)
#if os(macOS)
                .navigationSubtitle(Text(documentStore.document.date, format: .dateTime.year().month().day()))
#else
                .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
}

#Preview {
    NavigationStack {
        ArchiveListView(
            store: Store(initialState: ArchiveList.State()) {
                ArchiveList()
                    ._printChanges()
            }
        )
    }
}
