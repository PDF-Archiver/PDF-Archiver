//
//  AppFeature.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 05.07.25.
//

import ArchiverModels
import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        enum Tab: Hashable {
            case search
            case inbox
            case statistics
            #if !os(macOS)
            case settings
            #endif
            case sectionTags(String)
            case sectionYears(Int)
        }
        @Shared(.documents) var documents: IdentifiedArrayOf<Document> = []

        var selectedTab = Tab.search
        var tabTagSuggestions: [String] = []
        var tabYearSuggestions: [Int] = []
        var untaggedDocumentsCount: Int = 0
        var isDocumentLoading = true

        var archiveList = ArchiveList.State()
        var untaggedDocumentList = UntaggedDocumentList.State()
        var statistics = Statistics.State()
    }

    enum Action {
        case archiveList(ArchiveList.Action)
        case documentsChanged([Document])
        case isLoadingChanged(Bool)
        case onSetSelectedTab(State.Tab)
        case onTask
        case untaggedDocumentList(UntaggedDocumentList.Action)
        case statistics(Statistics.Action)
    }

    @Dependency(\.archiveStore) var archiveStore

    var body: some ReducerOf<Self> {
        // frist, run the ArchiveList reducer ...
        Scope(state: \.archiveList, action: \.archiveList) {
            ArchiveList()
        }
        Scope(state: \.untaggedDocumentList, action: \.untaggedDocumentList) {
            UntaggedDocumentList()
        }
        Scope(state: \.statistics, action: \.statistics) {
            Statistics()
        }

        // ... second, run AppFeature reducer, if we need to interact (from an AppFeature domain point of view) with it
        Reduce { state, action in
            switch action {
            case .archiveList(.documentDetails(.presented(.delegate(let delegateAction)))),
                    .untaggedDocumentList(.documentDetails(.presented(.delegate(let delegateAction)))):
                switch delegateAction {
                case .deleteDocument(let document):
                    _ = state.$documents.withLock { $0.remove(document) }
                    state.archiveList.documentDetails = nil
                    state.archiveList.$selectedDocumentId.withLock { $0 = nil }

                    return .run { _ in
                        try await archiveStore.deleteDocumentAt(document.url)
                    }
                }

            case .archiveList(.documentDetails(.presented(.showDocumentInformationForm(.delegate(let delegateAction))))),
                    .untaggedDocumentList(.documentDetails(.presented(.showDocumentInformationForm(.delegate(let delegateAction))))):
                switch delegateAction {
                case .saveDocument(let document):
                    state.$documents.withLock { documents in
                        let alreadyExistingElement = documents.updateOrAppend(document)
                        if alreadyExistingElement == nil {
                            XCTFail("Document that was saved not found in array - this should not happen")
                            documents.sort { $0.date < $1.date }
                        }
                    }
                    state.archiveList.documentDetails = nil
                    state.archiveList.$selectedDocumentId.withLock { $0 = nil }

                    #warning("select next document for tagging")

                    return .run { _ in
                        try await archiveStore.saveDocument(document)
                    }
                }

            case .archiveList:
                return .none

            case .documentsChanged(var documents):
                documents = documents
                    .sorted { $0.date < $1.date }
                    .reversed()
                state.$documents.withLock { $0 = IdentifiedArrayOf(uniqueElements: documents) }

                let taggedDocuments = documents
                    .filter { $0.isTagged }

                // create year suggestions
                let years = taggedDocuments
                    .reduce(into: Set<Int>()) { (result, document) in
                        result.insert(Calendar.current.component(.year, from: document.date))
                    }
                    .sorted()
                    .reversed()
                    .prefix(5)
                state.tabYearSuggestions = Array(years)

                // create tag suggestions
                var tagCountMap: [String: Int] = [:]
                for tag in taggedDocuments.flatMap(\.tags) {
                    tagCountMap[tag, default: 0] += 1
                }
                let top5Tags = tagCountMap
                    .sorted { lhs, rhs in
                        if lhs.value == rhs.value {
                            lhs.key < rhs.key
                        } else {
                            lhs.value > rhs.value
                        }
                    }
                    .prefix(5)
                    .map(\.key)
                state.tabTagSuggestions = Array(top5Tags)

                // also update suggestions in archive list
                state.archiveList.searchSuggestedTokens = [
                    top5Tags.prefix(3).map { ArchiveList.State.SearchToken.tag($0) },
                    years.prefix(3).map { ArchiveList.State.SearchToken.year($0) }
                ].flatMap(\.self)

                // update the untagged documents
                state.untaggedDocumentsCount = documents.filter(\Document.isTagged.flipped).count

                return .none

            case .isLoadingChanged(let isLoading):
                state.isDocumentLoading = isLoading
                return .none

            case .onSetSelectedTab(let tab):
                state.selectedTab = tab
                switch tab {
                case .search:
                    state.archiveList.searchTokens = []
                case .sectionTags(let tag):
                    state.archiveList.searchTokens = [.tag(tag)]
                case .sectionYears(let year):
                    state.archiveList.searchTokens = [.year(year)]
                case .inbox, .statistics:
                    break
                #if !os(macOS)
                case .settings:
                    break
                #endif
                }
                return .none

            case .onTask:
                return .run { send in
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for await documents in await archiveStore.documentChanges() {
                                await send(.documentsChanged(documents))
                            }
                        }
                        group.addTask {
                            for await isLoading in await archiveStore.isLoading() {
                                await send(.isLoadingChanged(isLoading))
                            }
                        }
                    }
                }

            case .untaggedDocumentList:
                return .none

            case .statistics:
                return .none
            }
        }
    }
}

struct AppView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Bindable var store: StoreOf<AppFeature>
    @State var searchText = ""

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.onSetSelectedTab)) {
            // Test this with macOS 26 - is there a search tab item?
//            Tab(value: AppFeature.State.Tab.search, role: .search) {
            Tab("Archive", systemImage: "magnifyingglass", value: AppFeature.State.Tab.search) {
                archiveList
            }

            Tab("Inbox", systemImage: "tray", value: AppFeature.State.Tab.inbox) {
                untaggedDocumentList
            }
            .badge(store.untaggedDocumentsCount)

            Tab("Statistics", systemImage: "chart.bar.xaxis", value: AppFeature.State.Tab.statistics) {
                StatisticsView(store: store.scope(state: \.statistics, action: \.statistics))
            }

            #if !os(macOS)
            Tab("Settings", systemImage: "gear", value: AppFeature.State.Tab.settings) {
                Text("TODO: Settings")
            }
            #endif

            TabSection("Tags") {
                ForEach(store.tabTagSuggestions, id: \.self) { tag in
                    Tab(tag, systemImage: "tag", value: AppFeature.State.Tab.sectionTags(tag)) {
                        archiveList
                    }
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)
            .hidden(horizontalSizeClass == .compact)

            TabSection("Years") {
                ForEach(store.tabYearSuggestions, id: \.self) { year in
                    Tab("\(year, format: .number.grouping(.never))", systemImage: "calendar", value: AppFeature.State.Tab.sectionYears(year)) {
                        archiveList
                    }
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)
            .hidden(horizontalSizeClass == .compact)
        }
        .tabViewStyle(.sidebarAdaptable)
        .toolbar {
            #warning("Not showing on iOS")
            ToolbarItem(placement: .destructiveAction) {
                ProgressView()
                    .controlSize(.small)
                    .opacity(store.isDocumentLoading ? 1 : 0)
            }
        }
        .task {
            await store.send(.onTask).finish()
        }
    }

    private var archiveList: some View {
        NavigationStack {
            ArchiveListView(store: store.scope(state: \.archiveList, action: \.archiveList))
                .navigationTitle("Archive")
        }
    }

    private var untaggedDocumentList: some View {
        NavigationStack {
            UntaggedDocumentListView(store: store.scope(state: \.untaggedDocumentList, action: \.untaggedDocumentList))
                .navigationTitle("Inbox")
        }
    }
}

#Preview {
    AppView(store: Store(initialState: AppFeature.State(isDocumentLoading: true)) {
        AppFeature()
            ._printChanges()
    }
    )
}
