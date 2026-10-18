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

        @SharedReader(.distinctFetch(FetchAllRequest(Document.list(tokens: [])))) var rows: [ArchiveSearchRow]
        @Shared(.selectedDocumentId) var selectedDocumentId: Int?
        @SharedReader(.premiumStatus) var premiumStatus: PremiumStatus = .loading
        var isSearching = false
        var isSearchPresented = false
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
        case onTask
        case premiumStatusChanged(PremiumStatus)
        case selectionChanged(Int?)
        case documentDetails(PresentationAction<DocumentDetails.Action>)
        case searchStateChanged(Bool)
        case searchTokensReplaced([State.SearchToken])
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.defaultDatabase) var database

    private enum CancelID {
        case search
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .documentDetails:
                return .none

            case .onTask:
                // A search typed before StoreKit answered has to gain its content hits, and a
                // lapse has to remove them again.
                return .publisher {
                    state.$premiumStatus.publisher
                        .removeDuplicates()
                        .map(Action.premiumStatusChanged)
                }

            case .premiumStatusChanged(let premiumStatus):
                // The publisher fires while `state.premiumStatus` still holds the old value, so
                // the query has to be built from the payload.
                return reloadRows(state, premiumStatus: premiumStatus)

            case .searchStateChanged(let isSearching):
                state.isSearching = isSearching
                return .none

            case .searchTokensReplaced(let tokens):
                state.searchText = ""
                state.searchTokens = tokens
                // a collapsed field would hide the token that filters the list
                state.isSearchPresented = !tokens.isEmpty
                return reloadRows(state, premiumStatus: state.premiumStatus)

            case .selectionChanged(let documentId):
                state.$selectedDocumentId.withLock { $0 = documentId }
                // The rows hold only what the list shows; the details need the whole document.
                state.documentDetails = documentId
                    .flatMap { id in
                        withErrorReporting { try database.read { try Document.find(id).fetchOne($0) } }
                    }
                    .flatMap(\.self)
                    .map { DocumentDetails.State(document: $0) }
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
                return reloadRows(state, premiumStatus: state.premiumStatus)

            case .binding(\.searchTokens):
                return reloadRows(state, premiumStatus: state.premiumStatus)

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
    private func reloadRows(_ state: State, premiumStatus: PremiumStatus) -> Effect<Action> {
        let query = ArchiveSearchQuery(text: state.searchText,
                                       tokens: state.searchTokens,
                                       includesContent: premiumStatus == .active)

        return .run { [rows = state.$rows] _ in
            try await clock.sleep(for: .milliseconds(150))
            guard query.hasFreeText else {
                _ = await withErrorReporting {
                    try await rows.load(.distinctFetch(FetchAllRequest(Document.list(tokens: query.tokens))))
                }
                return
            }

            do {
                try await rows.load(.distinctFetch(FetchAllRequest(Document.rankedSearch(query))))
            } catch {
                // FTS5 should not reject a sanitised query, but search must never go blank.
                reportIssue(error)
                _ = await withErrorReporting {
                    try await rows.load(.distinctFetch(FetchAllRequest(Document.list(tokens: query.tokens))))
                }
            }
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
}

struct ArchiveListView: View {
    @Bindable var store: StoreOf<ArchiveList>

    var body: some View {
        content
        #if os(macOS)
        .safeAreaInset(edge: .bottom) {
            ExchangeBannerSlot()
                // The SDK card ignores `dynamicTypeSize` on the Mac; scaling is the only way to shrink it.
                .scaleEffect(0.8, anchor: .bottom)
                .padding()
        }
        #endif
        .task {
            await store.send(.onTask).finish()
        }
        .modifier(SearchStateMonitor { _, newValue in
            store.send(.searchStateChanged(newValue))
        })
        .searchable(text: $store.searchText,
                    tokens: $store.searchTokens,
                    suggestedTokens: $store.searchSuggestedTokens,
                    isPresented: $store.isSearchPresented,
//                    placement: .toolbar,
                    prompt: String(localized: "Search your documents", bundle: #bundle)) { token in
            switch token {
            case .tag(let tag):
                Label(tag, systemImage: "tag")

            case .year(let year):
                Label("\(year, format: .number.grouping(.never))", systemImage: "calendar")

            case .text(let text):
                Label(text, systemImage: "text.viewfinder")

            case .indexFailed:
                Label(String(localized: "Failed", bundle: #bundle), systemImage: "exclamationmark.triangle")

            case .withoutText:
                Label(String(localized: "Without Text", bundle: #bundle), systemImage: "doc.text.magnifyingglass")
            }
        }
        .sensoryFeedback(.selection, trigger: store.selectedDocumentId)
        .documentDetailsDestination(item: $store.scope(\.$documentDetails, action: \.documentDetails))
    }

    @ViewBuilder
    private var content: some View {
        if store.rows.isEmpty {
            emptyState
                #if os(iOS)
                // Same spot as the banner's own section at the top of a filled list.
                .safeAreaInset(edge: .top) {
                    ExchangeBannerSlot()
                        .padding(.horizontal)
                }
                #endif
        } else {
            documentList
        }
    }

    @ViewBuilder
    private var emptyState: some View {
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
                .overlay(alignment: .bottom) {
                    premiumSearchHint
                }
        }
    }

    @ViewBuilder
    private var premiumSearchHint: some View {
        if store.premiumStatus != .active {
            Text("Search inside documents with Premium.", bundle: #bundle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private var documentList: some View {
        let selection = Binding(get: { store.selectedDocumentId },
                                set: { store.send(.selectionChanged($0)) })
        return List(selection: selection) {
            #if os(iOS)
            Section {
                // The list clips the row to the section's shape, so both get the same corners.
                ExchangeBannerSlot(style: .listRow)
                    .listRowInsets(EdgeInsets())
            }
            .listSectionSpacing(8)
            #endif

            Section {
                ForEach(store.rows) { row in
                    ArchiveListItemView(documentSpecification: row.specification,
                                        documentDate: row.date,
                                        documentTags: row.tags.sorted(),
                                        snippet: row.isFilenameHit ? nil : row.snippet)
                    .tag(row.id)
                }
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

#if DEBUG
#Preview("Ad in list") {
    archiveListWithAd(documents: ScreenshotCase.archivedDocuments)
}

#Preview("Ad in empty archive") {
    archiveListWithAd(documents: [])
}

@MainActor
private func archiveListWithAd(documents: [Document]) -> some View {
    prepareDependencies {
        // swiftlint:disable:next force_try
        try! $0.bootstrapDatabase()
        // swiftlint:disable:next force_try
        try! $0.defaultDatabase.write { db in
            guard !documents.isEmpty else { return }
            try Document.insert { documents }.execute(db)
            try DocumentTag.insert {
                documents.flatMap { document in document.tags.sorted().map { DocumentTag(documentID: document.id, tag: $0) } }
            }.execute(db)
        }
    }
    @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .loading
    $premiumStatus.withLock { $0 = .inactive }

    return NavigationStack {
        ArchiveListView(
            store: Store(initialState: ArchiveList.State()) {
                ArchiveList()
            }
        )
        .navigationTitle(Text(verbatim: "Archive"))
    }
    .environment(\.exchangeBanner, AnyView(AdPlaceholder()))
}

/// Stands in for the Kickstart card, whose SDK is linked into the app targets only.
private struct AdPlaceholder: View {
    @Environment(\.exchangeBannerStyle) private var style

    var body: some View {
        let cornerRadius: Double = style == .card ? 16 : 0
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.orange.gradient)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Kickstart Exchange").font(.headline)
                Text(verbatim: "Test advert – it works!").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(verbatim: "Get").bold().foregroundStyle(.red)
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(style == .card ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)))
    }
}
#endif
