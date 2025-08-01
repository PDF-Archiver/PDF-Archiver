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
        enum SearchToken: Hashable, Identifiable {
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
        var searchText = ""
        var searchTokens: [SearchToken] = []
        var searchSuggestedTokens: [SearchToken] = [.year(2025), .year(2024)]
        @Presents var documentDetails: DocumentDetails.State?

        private func getFilteredDocument() -> IdentifiedArrayOf<Document> {
            documents
                .filter(\.isTagged)
                .filter { document in
                for searchToken in searchTokens {
                    switch searchToken {
                    case .tag(let tag):
                        guard document.tags.contains(tag) else { return false }
                    case .year(let int):
                        guard document.url.lastPathComponent.hasPrefix("\(int)") else { return false }
                    case .text(let text):
                        guard document.url.lastPathComponent.contains(text) else { return false }
                    }
                }

                if !searchText.isEmpty {
                    let newSearchText = searchText.slugified(withSeparator: "-").lowercased()
                    return document.url.lastPathComponent.contains(newSearchText)
                }
                return true
                }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case documentDetails(PresentationAction<DocumentDetails.Action>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .documentDetails:
                return .none

            case .binding(\.selectedDocumentId):
                if let selectedDocumentId = state.selectedDocumentId,
                   let document = Shared(state.$documents[id: selectedDocumentId]) {
                    state.documentDetails = .init(document: document)
                } else {
                    state.documentDetails = nil
                }
                return .none
            case .binding(\.searchText):
                var searchText = state.searchText
                if searchText.popLast() == " " {
                    let newSearchText = searchText.slugified(withSeparator: "").lowercased()
                    state.searchTokens.append(.text(newSearchText))
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
        Group {
            if store.filteredDocuments.isEmpty {
                if store.searchText.isEmpty {
                    ContentUnavailableView("Empty Archive", systemImage: "archivebox", description: Text("Start scanning and tagging your first document."))
                } else {
                    let text = store.searchTokens.map({ "'\($0.value)' " }).joined() + store.searchText
                    ContentUnavailableView.search(text: text)
                }
            } else {
                List(store.filteredDocuments, selection: $store.selectedDocumentId) { document in
                    ArchiveListItemView(documentSpecification: document.specification,
                                        documentDate: document.date,
                                        documentTags: document.tags.sorted())
                    .tag(document.id)
                }
            }
        }
        .searchable(text: $store.searchText,
                    tokens: $store.searchTokens,
                    suggestedTokens: $store.searchSuggestedTokens,
//                    placement: .toolbar,
                    prompt: "Search your documents") { token in
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
        .navigationDestination(item: $store.scope(state: \.documentDetails, action: \.documentDetails)) { documentStore in
            DocumentDetailsView(store: documentStore)
                .navigationTitle(documentStore.document.specification)
#if os(macOS)
                .navigationSubtitle(Text(documentStore.document.date, format: .dateTime.year().month().day()))
#else
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        // editButton
                        Button {
                            documentStore.send(.onEditButtonTapped)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

#if os(macOS)
                        // showInFinderButton
                        Button(role: .none) {
                            NSWorkspace.shared.activateFileViewerSelecting([documentStore.document.url])
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                        }
#endif

                        ShareLink(Text(documentStore.document.filename), item: documentStore.document.url)

                        #warning("add this in iOS26")
//                        ToolbarSpacer()

                        // deleteButton
                        Button(role: .destructive) {
                            documentStore.send(.onDeleteDocumentButtonTapped)
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
#if os(macOS)
                    ToolbarItem(placement: .accessoryBar(id: "tags")) {
                        // fix for the high cpu usage
//                        HStack {
//                            ForEach(documentStore.document.tags.sorted(), id: \.self) { tag in
//                                Text(tag)
//                                    .frame(width: 50)
//                            }
//                        }
                        TagListView(tags: documentStore.document.tags.sorted(),
                                    isEditable: false,
                                    isMultiLine: false,
                                    tapHandler: nil)
                        .font(.caption)
                    }
#endif
                }
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
