//
//  AppFeature.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 05.07.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI
import TipKit

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        enum Tab: Hashable {
            case search
            case inbox
            case statistics
#warning("TODO: where should the settings be?")
//            #if !os(macOS)
            case settings
//            #endif
            case sectionTags(String)
            case sectionYears(Int)
        }
        @Shared(.documents) var documents: IdentifiedArrayOf<Document> = []
        @Shared(.tutorialShown) var tutorialShown: Bool
        @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .loading

        var scenePhase: ScenePhase?

        var selectedTab = Tab.search
        var tabTagSuggestions: [String] = []
        var tabYearSuggestions: [Int] = []
        var untaggedDocumentsCount: Int = 0
        var isDocumentLoading = true
        var showIapView = false

        var archiveList = ArchiveList.State()
        var untaggedDocumentList = UntaggedDocumentList.State()
        var statistics = Statistics.State()
        var settings = Settings.State()
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case archiveList(ArchiveList.Action)
        case documentsChanged([Document])
        case isLoadingChanged(Bool)
        case onCancelIapButtonTapped
        case onLongBackgroundTask
        case onScenePhaseChanged(old: ScenePhase, new: ScenePhase)
        case untaggedDocumentList(UntaggedDocumentList.Action)
        case updateWidget([Document])
        case prefetchDocuments([Document])
        case statistics(Statistics.Action)
        case settings(Settings.Action)
    }

    @Dependency(\.documentProcessor) var documentProcessor
    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.widgetStore) var widgetStore

    var body: some ReducerOf<Self> {
        BindingReducer()

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
        Scope(state: \.settings, action: \.settings) {
            Settings()
        }

        // ... second, run AppFeature reducer, if we need to interact (from an AppFeature domain point of view) with it
        Reduce { state, action in
            switch action {
            case .archiveList(.documentDetails(.presented(.delegate(let delegateAction)))),
                    .untaggedDocumentList(.documentDetails(.presented(.delegate(let delegateAction)))):
                switch delegateAction {
                case .deleteDocument(let document):
                    _ = state.$documents.withLock { $0.remove(document) }

                    selectNextDocument(current: document, &state)

                    return .run { _ in
                        try await archiveStore.deleteDocumentAt(document.url)
                    }
                }

            case .archiveList(.documentDetails(.presented(.showDocumentInformationForm(.delegate(let delegateAction))))),
                    .untaggedDocumentList(.documentDetails(.presented(.showDocumentInformationForm(.delegate(let delegateAction))))):
                switch delegateAction {
                case .saveDocument(let document, let shouldUpdatePdfMetadata):
                    state.$documents.withLock { documents in
                        let alreadyExistingElement = documents.updateOrAppend(document)
                        if alreadyExistingElement == nil {
                            XCTFail("Document that was saved not found in array - this should not happen")
                            documents.sort { $0.date < $1.date }
                        }
                    }
                    state.archiveList.documentDetails = nil
                    state.archiveList.$selectedDocumentId.withLock { $0 = nil }

                    if case .untaggedDocumentList = action {
                        selectNextDocument(current: document, &state)
                    }

                    return .run { _ in
                        try await archiveStore.saveDocument(document, shouldUpdatePdfMetadata)
                    }
                }

            case .archiveList:
                return .none

            case .binding(\.selectedTab):
                switch state.selectedTab {
                case .search:
                    state.archiveList.searchTokens = []
                case .sectionTags(let tag):
                    state.archiveList.searchTokens = [.tag(tag)]
                case .sectionYears(let year):
                    state.archiveList.searchTokens = [.year(year)]
                case .inbox:
                    state.showIapView = state.premiumStatus == .inactive

                case .statistics:
                    break
                    //                #if !os(macOS)
                case .settings:
                    break
                    //                #endif
                }
                return .none

            case .binding(\.premiumStatus):
                if state.selectedTab == .inbox {
                    state.showIapView = state.premiumStatus == .inactive
                    return .none
                } else {
                    guard state.premiumStatus != .inactive else { return .none }
                    state.showIapView = false
                    return .none
                }

            case .binding:
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
                let searchSuggestedTokens = [
                    top5Tags.prefix(3).map { ArchiveList.State.SearchToken.tag($0) },
                    years.prefix(3).map { ArchiveList.State.SearchToken.year($0) }
                ].flatMap(\.self)

                // update the untagged documents
                let untaggedDocuments = documents.filter(\Document.isTagged.flipped)
                state.untaggedDocumentsCount = untaggedDocuments.count

                let untaggedRemoteDocuments = untaggedDocuments.filter { !$0.isTagged && $0.downloadStatus == 0 }

                // https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance/#Sharing-logic-in-child-features
                return .concatenate(
                    reduce(into: &state, action: .archiveList(.searchSuggestionsUpdated(searchSuggestedTokens))),
                    .send(.prefetchDocuments(untaggedRemoteDocuments)),
                    .send(.updateWidget(documents)),
                )

            case .isLoadingChanged(let isLoading):
                state.isDocumentLoading = isLoading
                return .none

            case .onCancelIapButtonTapped:
                state.selectedTab = .search
                state.showIapView = false
                return .none

            case .onLongBackgroundTask:
                return .run { send in
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask(priority: .background) {
                            // check the temp folder at startup for new documents
                            await documentProcessor.triggerFolderObservation()
                        }
                        group.addTask(priority: .medium) {
                            for await documents in await archiveStore.documentChanges() {
                                await send(.documentsChanged(documents))
                            }
                        }
                        group.addTask(priority: .medium) {
                            for await isLoading in await archiveStore.isLoading() {
                                await send(.isLoadingChanged(isLoading))
                            }
                        }
                    }
                }

            case .onScenePhaseChanged(old: let old, new: let new):
                // there might be situations where a user has made some document modifications while the app is in background
                // we prevent an inconsistency by triggering a document reload when the app enters forground
                // since this will already be done initially, we don't want to do it while the app is loading
                if old != new,
                   new == .active,
                   !state.isDocumentLoading {
                    return .run { _ in
                        try await archiveStore.reloadDocuments()
                    }
                }

                return .none

            case .untaggedDocumentList:
                return .none

            case .updateWidget(let documents):
                return .run { _ in
                    await widgetStore.updateWidgetWith(documents)
                }

            case .prefetchDocuments(let documents):
                return .run { _ in
                    for document in documents {
                        try? await archiveStore.startDownloadOf(document.url)
                    }
                }

            case .settings(.premiumSection(.delegate(let delegateAction))):
                switch delegateAction {
                case .onShowIapButtonTapped:
                    state.showIapView = true
                }
                return .none

            case .settings:
                return .none

            case .statistics:
                return .none

            }
        }
    }

    private func selectNextDocument(current document: Document, _ state: inout State) {
        let nextDocument = state.documents.elements.first { $0.id != document.id && $0.isTagged == document.isTagged }
        if document.isTagged {
            if let nextDocument {
                state.archiveList.documentDetails = .init(document: Shared(value: nextDocument))
            } else {
                state.archiveList.documentDetails = nil
            }
            state.archiveList.$selectedDocumentId.withLock { $0 = nextDocument?.id }
        } else {
            if let nextDocument {
                state.untaggedDocumentList.documentDetails = .init(document: Shared(value: nextDocument))
            } else {
                state.untaggedDocumentList.documentDetails = nil
            }
            state.untaggedDocumentList.$selectedDocumentId.withLock { $0 = nextDocument?.id }
        }
    }
}

struct AppView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.scenePhase) var scenePhase
    @Bindable var store: StoreOf<AppFeature>
    @State private var tips = TipGroup(.ordered) {
        ScanShareTip()
        AfterFirstImportTip()
    }

    init(store: StoreOf<AppFeature>) {
        self.store = store

        Task.detached(priority: .background) {
            await store.send(.onLongBackgroundTask).finish()
        }
    }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            // Test this with macOS 26 - is there a search tab item?
//            Tab(value: AppFeature.State.Tab.search, role: .search) {
//            Tab(LocalizedStringResource("Archive", bundle: .module), systemImage: "magnifyingglass", value: AppFeature.State.Tab.search) {
            Tab(String(localized: "Archive", bundle: .module), systemImage: "magnifyingglass", value: AppFeature.State.Tab.search) {
                archiveList
                    .modifier(ScanButtonModifier(showButton: store.archiveList.documentDetails == nil, currentTip: store.tutorialShown ? tips.currentTip : nil))
            }

            Tab(String(localized: "Inbox", bundle: .module), systemImage: "tray", value: AppFeature.State.Tab.inbox) {
                untaggedDocumentList
            }
            .badge(store.untaggedDocumentsCount)

            Tab(String(localized: "Statistics", bundle: .module), systemImage: "chart.bar.xaxis", value: AppFeature.State.Tab.statistics) {
                StatisticsView(store: store.scope(state: \.statistics, action: \.statistics))
            }

//            #if !os(macOS)
            Tab(String(localized: "Settings", bundle: .module), systemImage: "gear", value: AppFeature.State.Tab.settings) {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
//            #endif

            TabSection(String(localized: "Tags", bundle: .module)) {
                ForEach(store.tabTagSuggestions, id: \.self) { tag in
                    Tab(tag, systemImage: "tag", value: AppFeature.State.Tab.sectionTags(tag)) {
                        archiveList
                    }
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)
            .hidden(horizontalSizeClass == .compact)

            TabSection("\(String(localized: "Years", bundle: .module))") {
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
        .modifier(AlertDataModelProvider())
        .modifier(IAP(premiumStatus: $store.premiumStatus))
        .sheet(isPresented: $store.tutorialShown.flipped) {
            OnboardingView(isPresented: $store.tutorialShown.flipped)
                #if os(macOS)
                .frame(width: 500, height: 400)
                #endif
        }
        .sheet(isPresented: $store.showIapView, onDismiss: {
            store.send(.onCancelIapButtonTapped)
        }, content: {
            IAPView {
                store.send(.onCancelIapButtonTapped)
            }
        })
        .onChange(of: scenePhase) { old, new in
            store.send(.onScenePhaseChanged(old: old, new: new))
        }
    }

    private var archiveList: some View {
        NavigationStack {
            ArchiveListView(store: store.scope(state: \.archiveList, action: \.archiveList))
                .navigationTitle(Text("Archive", bundle: .module))
                .toolbar {
                    toolbarLoadingSpinner
                }
        }
    }

    private var untaggedDocumentList: some View {
        NavigationStack {
            UntaggedDocumentListView(store: store.scope(state: \.untaggedDocumentList, action: \.untaggedDocumentList))
                .navigationTitle(Text("Inbox", bundle: .module))
                .toolbar {
                    toolbarLoadingSpinner
                }
        }
    }

    private var toolbarLoadingSpinner: some ToolbarContent {
        ToolbarItem(placement: .destructiveAction) {
            ProgressView()
                #if os(macOS)
                .controlSize(.small)
                #endif
                .opacity(store.isDocumentLoading ? 1 : 0)
        }
    }
}

#Preview {
    AppView(store: Store(initialState: AppFeature.State(isDocumentLoading: true)) {
        AppFeature()
            ._printChanges()
    })
}
