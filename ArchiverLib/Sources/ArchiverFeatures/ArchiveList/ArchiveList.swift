//
//  ArchiveList.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 03.07.25.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Shared
import SQLiteData
import SwiftUI

@Reducer
struct ArchiveList {
    @ObservableState
    struct State: Equatable {
        typealias SearchToken = ArchiverDatabase.SearchToken

        @FetchAll(Document.list(tokens: [])) var rows: [ArchiveSearchRow]
        @Shared(.selectedDocumentId) var selectedDocumentId: Int?
        @SharedReader(.premiumStatus) var premiumStatus: PremiumStatus = .loading
        var isSearching = false
        var searchText = ""
        var searchTokens: [SearchToken] = []
        // fallback until real suggestions are derived from the documents in AppFeature
        var searchSuggestedTokens: [SearchToken] = {
            let currentYear = Calendar.current.component(.year, from: Date())
            return [.year(currentYear), .year(currentYear - 1)]
        }()
        @Presents var documentDetails: DocumentDetails.State?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case selectionChanged(Int?)
        case documentDetails(PresentationAction<DocumentDetails.Action>)
        case searchStateChanged(Bool)
    }

    @Dependency(\.mainQueue) var mainQueue

    private enum CancelID {
        case search
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
                // A fetch wrapper yields a plain array; ranked results are capped, the list is a few thousand.
                state.documentDetails = documentId
                    .flatMap { id in state.rows.first { $0.id == id } }
                    .map { DocumentDetails.State(document: $0.document) }
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
                return reloadRows(state)

            case .binding(\.searchTokens):
                return reloadRows(state)

            case .binding:
                return .none
            }
        }
        .ifLet(\.$documentDetails, action: \.documentDetails) {
            DocumentDetails()
        }
    }

    /// Shared by every trigger; a private helper rather than an `Effect.send`, which TCA reserves
    /// for child-to-parent messages.
    private func reloadRows(_ state: State) -> Effect<Action> {
        var tokens = state.searchTokens
        let freeText = state.searchText.slugified(withSeparator: "-")
        if !freeText.isEmpty {
            tokens.append(.text(freeText))
        }

        return .run { [rows = state.$rows, tokens] _ in
            await withErrorReporting {
                try await rows.load(Document.list(tokens: tokens))
            }
        }
        .debounce(id: CancelID.search, for: .milliseconds(150), scheduler: mainQueue)
    }
}

struct ArchiveListView: View {
    @Bindable var store: StoreOf<ArchiveList>

    var body: some View {
        let rows = store.rows
        Group {
            if rows.isEmpty {
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
                List(rows, selection: Binding(get: { store.selectedDocumentId }, set: { store.send(.selectionChanged($0)) })) { row in
                    ArchiveListItemView(documentSpecification: row.document.specification,
                                        documentDate: row.document.date,
                                        documentTags: row.document.tags.sorted())
                    .tag(row.id)
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
