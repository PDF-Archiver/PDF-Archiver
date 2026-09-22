//
//  AppFeature.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 05.07.25.
//

import ArchiverDatabase
import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import OSLog
import Shared
import SQLiteData
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
            #if !os(macOS)
            case settings
            #endif
            case sectionTags(String)
            case sectionYears(Int)
        }
        @Fetch(AppProjectionRequest()) var projection = AppProjection()
        @FetchAll(Document.inbox) var inbox: [Document]
        @Shared(.tutorialShown) var tutorialShown: Bool
        @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .loading

        var scenePhase: ScenePhase?

        var selectedTab = Tab.search
        var showScanButton: Bool {
            selectedTab == .search && archiveList.documentDetails == nil && !archiveList.isSearching
        }

        var archiveList = ArchiveList.State()
        var untaggedDocumentList = UntaggedDocumentList.State()
        var statistics = Statistics.State()
        var settings = Settings.State()
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case archiveList(ArchiveList.Action)
        case inboxChanged([Document])
        case onLongBackgroundTask
        case onScenePhaseChanged(old: ScenePhase, new: ScenePhase)
        case onWidgetTagTapped
        case premiumStatusChanged(PremiumStatus)
        case projectionChanged(AppProjection)
        case untaggedDocumentList(UntaggedDocumentList.Action)
        case statistics(Statistics.Action)
        case settings(Settings.Action)
    }

    @Dependency(\.defaultDatabase) var database
    @Dependency(\.documentProcessor) var documentProcessor
    @Dependency(\.indexScheduler) var indexScheduler
    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.widgetStore) var widgetStore
    @Dependency(\.premium) var premium

    private enum CancelID {
        case untaggedProcessing
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        // frist, run the ArchiveList reducer ...
        Scope(\.archiveList, action: \.archiveList) {
            ArchiveList()
        }
        Scope(\.untaggedDocumentList, action: \.untaggedDocumentList) {
            UntaggedDocumentList()
        }
        Scope(\.statistics, action: \.statistics) {
            Statistics()
        }
        Scope(\.settings, action: \.settings) {
            Settings()
        }

        // ... second, run AppFeature reducer, if we need to interact (from an AppFeature domain point of view) with it
        Reduce { state, action in
            switch action {
            case .archiveList(.documentDetails(.presented(.delegate(let delegateAction)))),
                    .untaggedDocumentList(.documentDetails(.presented(.delegate(let delegateAction)))):
                switch delegateAction {
                case .deleteDocument(let document):
                    // No optimistic removal: the row leaves the list when the provider event arrives.
                    selectNextDocument(current: document, &state)

                    return .run { _ in
                        do {
                            try await archiveStore.deleteDocumentAt(document.url)
                        } catch {
                            Logger.app.error("Failed to delete document", metadata: [
                                "documentId": "\(document.id)",
                                "error": "\(LogRedact.describe(error))"
                            ])
                        }
                    }
                }

            case .archiveList(.documentDetails(.presented(.showDocumentInformationForm(.delegate(let delegateAction))))),
                    .untaggedDocumentList(.documentDetails(.presented(.showDocumentInformationForm(.delegate(let delegateAction))))):
                switch delegateAction {
                case .saveDocument(let document, let shouldUpdatePdfMetadata):
                    state.archiveList.documentDetails = nil
                    state.archiveList.$selectedDocumentId.withLock { $0 = nil }

                    if case .untaggedDocumentList = action {
                        selectNextDocument(current: document, &state)
                    }

                    return .run { _ in
                        do {
                            try await archiveStore.saveDocument(document, shouldUpdatePdfMetadata)
                        } catch {
                            Logger.app.error("Failed to save document", metadata: [
                                "documentId": "\(document.id)",
                                "error": "\(LogRedact.describe(error))"
                            ])
                        }
                    }
                }

            case .archiveList:
                return .none

            case .binding(\.selectedTab):
                // deselect the last document because the user could not selected e.g. the inspector when switching tabs
                state.archiveList.$selectedDocumentId.withLock { $0 = nil }

                // switch tab
                switch state.selectedTab {
                case .search:
                    state.archiveList.searchTokens = []

                case .sectionTags(let tag):
                    state.archiveList.searchTokens = [.tag(tag)]

                case .sectionYears(let year):
                    state.archiveList.searchTokens = [.year(year)]

                case .inbox, .statistics:
                    break

                #if os(iOS)
                case .settings:
                    break
                #endif
                }
                return .none

            case .binding:
                return .none

            case .inboxChanged(let inbox):
                let remoteDocuments = inbox.filter { $0.downloadStatus == 0 }

                return .merge(
                    .run { _ in
                        await withTaskGroup(of: Void.self) { group in
                            for document in remoteDocuments {
                                group.addTask {
                                    do {
                                        try await archiveStore.startDownloadOf(document.url)
                                    } catch {
                                        Logger.app.error("Failed to start inbox prefetch download", metadata: [
                                            "documentId": "\(document.id)",
                                            "error": "\(LogRedact.describe(error))"
                                        ])
                                    }
                                }
                            }
                        }
                    },
                    // The pass restarts whenever the inbox changes; the OCR marker and the AI
                    // cache make repeated runs cheap no-ops.
                    .run { _ in
                        // Tagged documents are the model's tag vocabulary and description examples.
                        let context = await withErrorReporting {
                            try await database.read { db in
                                try Document.aiContext().fetchAll(db)
                            }
                        }
                        let result = await documentProcessor.processUntaggedDocuments(inbox + (context ?? []))

                        // An OCR run rewrites the PDF in place. Whether `NSMetadataQuery` reports
                        // that for its own process is undocumented, so the rescan is explicit.
                        guard result.ocrCount > 0 else { return }
                        await withErrorReporting {
                            try await archiveStore.reloadDocuments()
                        }
                    }
                    .cancellable(id: CancelID.untaggedProcessing, cancelInFlight: true)
                )

            case .projectionChanged(let projection):
                let suggestedTokens = [
                    projection.topTags.prefix(3).map { ArchiveList.State.SearchToken.tag($0) },
                    projection.taggedYears.prefix(3).map { ArchiveList.State.SearchToken.year($0) }
                ].flatMap(\.self)
                // The projection republishes on every write, while the top three tags and years
                // almost never move. Assigning anyway would invalidate the suggestions list under
                // the open suggestions window, which is where AppKit loses its first responder.
                if state.archiveList.searchSuggestedTokens != suggestedTokens {
                    state.archiveList.searchSuggestedTokens = suggestedTokens
                }

                return .run { [yearCounts = projection.yearCounts, untaggedCount = projection.untaggedCount] _ in
                    await widgetStore.updateWidget(yearCounts, untaggedCount)
                }

            case .onLongBackgroundTask:
                return .merge(
                    .publisher { state.$projection.publisher.map(Action.projectionChanged) },
                    .publisher { state.$inbox.publisher.map(Action.inboxChanged) },
                    // Own effect: what a support report needs as its baseline must not wait behind
                    // the startup work below.
                    .run(priority: .background) { _ in
                        await AppStateLog.log()
                    },
                    .run(priority: .background) { _ in
                        // check the temp folder at startup for new documents
                        await documentProcessor.processStagedFiles()

                        // trigger task scheduling - the handler itself is registered
                        // in the app initializer, as required by BGTaskScheduler
                        await indexScheduler.schedule()
                    },
                    // A separate effect so the premium status, which gates the UI, never queues
                    // behind processStagedFiles().
                    .run(priority: .medium) { send in
                        await send(.premiumStatusChanged(premium.currentStatus()))
                        for await _ in premium.transactionUpdates() {
                            await send(.premiumStatusChanged(premium.currentStatus()))
                        }
                    },
                    .run(priority: .background) { _ in
                        // Its own effect: the scheduling above returns at once, while this one runs
                        // for as long as the app is open.
                        await indexScheduler.indexWhileAppIsOpen()
                    }
                )

            case .onScenePhaseChanged(old: let old, new: let new):
                guard old != new, new == .active else { return .none }

                // A subscription that expired in the background produces no transaction, so this
                // is the only place that notices it - independent of the document reload below.
                let premiumEffect = Effect<Action>.run { send in
                    await send(.premiumStatusChanged(premium.currentStatus()))
                }

                // there might be situations where a user has made some document modifications while the app is in background
                // we prevent an inconsistency by triggering a document reload when the app enters forground
                // since this will already be done initially, we don't want to do it while the app is loading
                guard !state.projection.isReconciling else { return premiumEffect }

                return .merge(
                    premiumEffect,
                    .run { _ in
                        await withThrowingTaskGroup(of: Void.self) { group in
                            group.addTask(priority: .background) {
                                await documentProcessor.processStagedFiles()
                            }
                            group.addTask(priority: .medium) {
                                try await archiveStore.reloadDocuments()
                            }
                        }
                    }
                )

            case .onWidgetTagTapped:
                state.selectedTab = .inbox
                return .none

            case .untaggedDocumentList(.delegate(let delegateAction)):
                switch delegateAction {
                case .onCancelIapButtonTapped:
                    state.selectedTab = .search
                    return .none

                case .onIapPurchaseCompleted:
                    // A same-device purchase completes through `Product.PurchaseResult`, not
                    // `Transaction.updates`, so this is the only trigger for it.
                    return .run { send in
                        await send(.premiumStatusChanged(premium.currentStatus()))
                    }
                }

            case .untaggedDocumentList:
                return .none

            case .premiumStatusChanged(let status):
                state.$premiumStatus.withLock { $0 = status }
                return .none

            case .settings(.premiumSection(.delegate(let delegateAction))):
                switch delegateAction {
                case .switchToInboxTab:
                    state.selectedTab = .inbox
                    return .none
                }

            case .settings:
                return .none

            case .statistics:
                return .none
            }
        }
    }

    /// Synchronous on purpose: a database read would add an async hop to the save flow and break
    /// the immediate navigation transition.
    private func selectNextDocument(current document: Document, _ state: inout State) {
        if document.isTagged {
            let nextDocument = state.archiveList.rows.first { $0.id != document.id }?.document
            if let nextDocument {
                state.archiveList.documentDetails = .init(document: nextDocument)
            } else {
                state.archiveList.documentDetails = nil
            }
            state.archiveList.$selectedDocumentId.withLock { $0 = nextDocument?.id }
        } else {
            let nextDocument = state.untaggedDocumentList.documents.first { $0.id != document.id }
            if let nextDocument {
                state.untaggedDocumentList.documentDetails = .init(document: nextDocument)
                // always show the inspector when the document is not tagged
                state.untaggedDocumentList.documentDetails?.showInspector = true
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
    }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            #if os(iOS)
            Tab(value: AppFeature.State.Tab.search, role: .search) {
                archiveList
                    .modifier(ScanButtonModifier(showButton: store.showScanButton, currentTip: store.tutorialShown ? tips.currentTip : nil))
            }
            #else
            if #available(macOS 26, *) {
                Tab(value: AppFeature.State.Tab.search, role: .search) {
                    archiveList
                        .modifier(ScanButtonModifier(showButton: store.showScanButton, currentTip: store.tutorialShown ? tips.currentTip : nil))
                }
            } else {
                // old fallback solution
                Tab(String(localized: "Archive", bundle: #bundle), systemImage: "magnifyingglass", value: AppFeature.State.Tab.search) {
                    archiveList
                        .modifier(ScanButtonModifier(showButton: store.showScanButton, currentTip: store.tutorialShown ? tips.currentTip : nil))
                }
            }
            #endif

            Tab(String(localized: "Inbox", bundle: #bundle), systemImage: "tray", value: AppFeature.State.Tab.inbox) {
                untaggedDocumentList
            }
            .badge(store.projection.untaggedCount)

            Tab(String(localized: "Statistics", bundle: #bundle), systemImage: "chart.bar.xaxis", value: AppFeature.State.Tab.statistics) {
                StatisticsView(store: store.scope(\.statistics, action: \.statistics))
            }

            #if !os(macOS)
            Tab(String(localized: "Settings", bundle: #bundle), systemImage: "gear", value: AppFeature.State.Tab.settings) {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
            #endif

            TabSection(String(localized: "Tags", bundle: #bundle)) {
                ForEach(store.projection.topTags, id: \.self) { tag in
                    Tab(tag, systemImage: "tag", value: AppFeature.State.Tab.sectionTags(tag)) {
                        archiveList
                    }
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)
            .hidden(horizontalSizeClass == .compact)

            TabSection("\(String(localized: "Years", bundle: #bundle))") {
                ForEach(store.projection.taggedYears, id: \.self) { year in
                    Tab("\(year, format: .number.grouping(.never))", systemImage: "calendar", value: AppFeature.State.Tab.sectionYears(year)) {
                        archiveList
                    }
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)
            .hidden(horizontalSizeClass == .compact)
        }
        .tabViewStyle(.sidebarAdaptable)
        .task {
            await store.send(.onLongBackgroundTask).finish()
        }
        .apply { content in
            #if os(iOS)
            if #available(iOS 26.0, *) {
                content.tabBarMinimizeBehavior(.onScrollDown)
            } else {
                content
            }
            #else
            content
            #endif
        }
        .modifier(AlertDataModelProvider())
        .sheet(isPresented: Binding(store.$tutorialShown).flipped) {
            OnboardingView(isPresented: Binding(store.$tutorialShown).flipped)
                #if os(macOS)
                .frame(width: 500, height: 400)
                #endif
        }
        .onChange(of: scenePhase) { old, new in
            store.send(.onScenePhaseChanged(old: old, new: new))
        }
        .onOpenURL { url in
            switch url {
            case DeepLink.tag.url:
                store.send(.onWidgetTagTapped)

            default:
                break
            }
        }
    }

    private var archiveList: some View {
        NavigationStack {
            ArchiveListView(store: store.scope(\.archiveList, action: \.archiveList))
                .navigationTitle(Text("Archive", bundle: #bundle))
                .toolbar {
                    loadingIndicator
                }
        }
    }

    private var untaggedDocumentList: some View {
        NavigationStack {
            UntaggedDocumentListView(store: store.scope(\.untaggedDocumentList, action: \.untaggedDocumentList))
                .navigationTitle(Text("Inbox", bundle: #bundle))
                .toolbar {
                    loadingIndicator
                }
        }
    }

    @ToolbarContentBuilder
    private var loadingIndicator: some ToolbarContent {
        if store.projection.isReconciling {
            #if os(macOS)
            ToolbarItem(placement: .status) {
                ProgressView()
                    .frame(width: 32, height: 32)
                    .controlSize(.small)
            }
            #else
            ToolbarItem(placement: .automatic) {
                ProgressView()
            }
            #endif
        }
    }
}

#Preview {
    AppView(store: Store(initialState: AppFeature.State()) {
        AppFeature()
            ._printChanges()
    })
}
