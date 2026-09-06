import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import DocumentProcessingPipeline
import Foundation
import SQLiteData
import Testing

@testable import ArchiverFeatures

@MainActor
@Suite(.dependencies { try $0.bootstrapDatabase() })
struct AppFeatureTests {
    // MARK: - Tab Selection Tests

    @Test
    func tabSelectionUpdatesSearchTokens() async throws {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.mainQueue = .immediate
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.binding(.set(\.selectedTab, .sectionTags("invoice"))))
        #expect(store.state.archiveList.searchTokens == [.tag("invoice")])

        await store.send(.binding(.set(\.selectedTab, .sectionYears(2024))))
        #expect(store.state.archiveList.searchTokens == [.year(2024)])

        await store.send(.binding(.set(\.selectedTab, .search)))
        #expect(store.state.archiveList.searchTokens.isEmpty)
    }

    @Test
    func tabSelectionClearsSelectedDocument() async throws {
        let store = TestStore(initialState: AppFeature.State(
            archiveList: ArchiveList.State(selectedDocumentId: Shared(value: 42))
        )) {
            AppFeature()
        } withDependencies: {
            $0.mainQueue = .immediate
        }

        await store.send(.binding(.set(\.selectedTab, .inbox))) {
            $0.selectedTab = .inbox
            $0.archiveList.$selectedDocumentId.withLock { $0 = nil }
        }
    }

    // MARK: - Projection Tests

    @Test
    func theProjectionFeedsTheTabSuggestionsAndTheWidget() async throws {
        try await Self.seedArchive()
        let widgetUpdates = LockIsolated<[([Int: Int], Int)]>([])
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.widgetStore.updateWidget = { yearCounts, untaggedCount in
                widgetUpdates.withValue { $0.append((yearCounts, untaggedCount)) }
            }
        }
        try await store.state.$projection.load()

        await store.send(.projectionChanged(store.state.projection)) {
            $0.archiveList.searchSuggestedTokens = [.tag("bill"), .tag("work"), .year(2024), .year(2023)]
        }

        #expect(widgetUpdates.value.first?.0 == [2024: 3, 2023: 1])
        #expect(widgetUpdates.value.first?.1 == 1)
    }

    /// The tab suggestions and the widget at launch depend on the bridge itself delivering, not
    /// on anyone sending `projectionChanged` by hand.
    @Test
    func theLongBackgroundTaskBridgesTheProjectionAndTheInbox() async throws {
        try await Self.seedArchive()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.documentProcessor.processStagedFiles = { }
            $0.documentProcessor.processUntaggedDocuments = { _ in UntaggedProcessingResult(ocrCount: 0, aiCacheCount: 0) }
            $0.indexScheduler.schedule = { }
            $0.widgetStore.updateWidget = { _, _ in }
            $0.archiveStore.startDownloadOf = { _ in }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        let task = await store.send(.onLongBackgroundTask)

        await store.receive(\.projectionChanged)
        #expect(store.state.archiveList.searchSuggestedTokens.contains(.tag("bill")))

        await store.receive(\.inboxChanged)
        await task.cancel()
    }

    /// A fresh scan falls back to its creation-date year - today's - which must not reach the tab bar.
    @Test
    func anUntaggedDocumentDoesNotAppearInTheYearSuggestions() async throws {
        let currentYear = Calendar.current.component(.year, from: Date())
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try db.seed {
                Document(id: -10, rootKey: "test", url: URL(filePath: "/Archive/2020/2020-01-01--filed__bill.pdf"), date: appFeatureDate(2020), specification: "filed", tags: ["bill"], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
                Document(id: -11, rootKey: "test", url: URL(filePath: "/Archive/untagged/scan.pdf"), date: Date(), specification: "scan", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
                DocumentTag(documentID: -10, tag: "bill")
            }
        }

        let state = AppFeature.State()
        try await state.$projection.load()

        #expect(state.projection.taggedYears == [2020])
        #expect(!state.projection.taggedYears.contains(currentYear))
        // The widget and the statistics still count it.
        #expect(state.projection.yearCounts == [2020: 1, currentYear: 1])
    }

    // MARK: - Inbox Tests

    @Test
    func theInboxDrivesThePrefetchAndTheUntaggedProcessing() async throws {
        let downloaded = LockIsolated<[URL]>([])
        let processed = LockIsolated<[Document]>([])
        let remote = Document.mock(url: URL(filePath: "/Archive/untagged/remote.pdf"), isTagged: false, downloadStatus: 0)
        let local = Document.mock(url: URL(filePath: "/Archive/untagged/local.pdf"), isTagged: false, downloadStatus: 1)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.archiveStore.startDownloadOf = { url in downloaded.withValue { $0.append(url) } }
            $0.documentProcessor.processUntaggedDocuments = { documents in
                processed.withValue { $0 = documents }
                return UntaggedProcessingResult(ocrCount: 0, aiCacheCount: 0)
            }
        }

        await store.send(.inboxChanged([remote, local]))
        await store.finish()

        #expect(downloaded.value == [remote.url])
        #expect(processed.value.map(\.id) == [remote.id, local.id])
    }

    // MARK: - Scene Phase Tests

    @Test
    func scenePhaseActiveReloadsDocuments() async throws {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.documentProcessor.processStagedFiles = { }
            $0.archiveStore.reloadDocuments = { }
        }

        await store.send(.onScenePhaseChanged(old: .background, new: .active))
    }

    @Test
    func scenePhaseDoesNotReloadWhileReconciling() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try IndexerState.find(IndexerState.singletonID).update { $0.isReconciling = true }.execute(db)
        }

        let state = AppFeature.State()
        try await state.$projection.load()
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.onScenePhaseChanged(old: .background, new: .active))
    }

    // MARK: - Widget Tests

    @Test
    func widgetTagTappedSwitchesToInbox() async throws {
        let store = TestStore(initialState: AppFeature.State(selectedTab: .search)) {
            AppFeature()
        }

        await store.send(.onWidgetTagTapped) {
            $0.selectedTab = .inbox
        }
    }

    // MARK: - Delete Document Tests

    @Test
    func deletingAnInboxDocumentSelectsTheNextOne() async throws {
        try await Self.seedInbox()
        var state = AppFeature.State()
        state.selectedTab = .inbox
        try await state.untaggedDocumentList.$documents.load()
        let current = try #require(state.untaggedDocumentList.documents.first { $0.id == -21 })
        let next = try #require(state.untaggedDocumentList.documents.first { $0.id == -22 })
        state.untaggedDocumentList.documentDetails = .init(document: current)
        state.untaggedDocumentList.$selectedDocumentId.withLock { $0 = current.id }

        let deleted = LockIsolated<[URL]>([])
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.archiveStore.deleteDocumentAt = { url in deleted.withValue { $0.append(url) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.untaggedDocumentList(.documentDetails(.presented(.delegate(.deleteDocument(current))))))
        await store.finish()

        #expect(store.state.untaggedDocumentList.documentDetails?.document.id == next.id)
        #expect(store.state.untaggedDocumentList.selectedDocumentId == next.id)
        #expect(deleted.value == [current.url])
    }

    @Test
    func deletingTheLastInboxDocumentClosesTheDetails() async throws {
        try await Self.seedInbox()
        var state = AppFeature.State()
        try await state.untaggedDocumentList.$documents.load()
        let onlyRemaining = try #require(state.untaggedDocumentList.documents.first { $0.id == -21 })
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try Document.find(-22).delete().execute(db)
        }
        try await state.untaggedDocumentList.$documents.load()
        state.untaggedDocumentList.documentDetails = .init(document: onlyRemaining)

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.archiveStore.deleteDocumentAt = { _ in }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.untaggedDocumentList(.documentDetails(.presented(.delegate(.deleteDocument(onlyRemaining))))))
        await store.finish()

        #expect(store.state.untaggedDocumentList.documentDetails == nil)
    }

    // MARK: - Helpers

    private static func seedArchive() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try db.seed {
                Document(id: -1, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-01--a__bill_work.pdf"), date: appFeatureDate(2024), specification: "a", tags: ["bill", "work"], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
                Document(id: -2, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-02-01--b__bill.pdf"), date: appFeatureDate(2024), specification: "b", tags: ["bill"], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
                Document(id: -3, rootKey: "test", url: URL(filePath: "/Archive/2023/2023-01-01--c__work.pdf"), date: appFeatureDate(2023), specification: "c", tags: ["work"], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
                Document(id: -4, rootKey: "test", url: URL(filePath: "/Archive/untagged/scan.pdf"), date: appFeatureDate(2024), specification: "scan", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
                DocumentTag(documentID: -1, tag: "bill")
                DocumentTag(documentID: -1, tag: "work")
                DocumentTag(documentID: -2, tag: "bill")
                DocumentTag(documentID: -3, tag: "work")
            }
        }
    }

    private static func seedInbox() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try db.seed {
                Document(id: -21, rootKey: "test", url: URL(filePath: "/Archive/untagged/scan1.pdf"), date: appFeatureDate(2024), specification: "scan1", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
                Document(id: -22, rootKey: "test", url: URL(filePath: "/Archive/untagged/scan2.pdf"), date: appFeatureDate(2023), specification: "scan2", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
            }
        }
    }
}

private func appFeatureDate(_ year: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar.date(from: DateComponents(year: year, month: 6, day: 1)) ?? .distantPast
}
