import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import ArchiverFeatures

@MainActor
@Suite(.dependencies {
    $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
    try $0.bootstrapDatabase()
    try $0.defaultDatabase.write { db in
        try db.seed {
            Document(id: -1, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-01--important-invoice__tag1.pdf"), date: Date(timeIntervalSince1970: 100), specification: "important invoice", tags: ["tag1"], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
            Document(id: -2, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-02--receipt__tag2.pdf"), date: Date(timeIntervalSince1970: 200), specification: "receipt", tags: ["tag2"], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
            Document(id: -3, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-03--rechnung-fuer-buero__tag2.pdf"), date: Date(timeIntervalSince1970: 300), specification: "rechnung fuer buero", tags: ["tag2"], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
            DocumentTag(documentID: -1, tag: "tag1")
            DocumentTag(documentID: -2, tag: "tag2")
            DocumentTag(documentID: -3, tag: "tag2")
        }
    }
})
struct ArchiveListTests {
    // MARK: - Search Token Tests

    @Test
    func addingTagSearchToken() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        } withDependencies: {
            $0.mainQueue = .immediate
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.binding(.set(\.searchTokens, [.tag("tag1")])))

        #expect(store.state.searchTokens == [.tag("tag1")])
        #expect(store.state.rows.map(\.id) == [-1])
    }

    @Test
    func addingYearSearchToken() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        } withDependencies: {
            $0.mainQueue = .immediate
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.binding(.set(\.searchTokens, [.year(1970)])))

        #expect(store.state.rows.count == 3)
    }

    @Test
    func aSpaceTurnsTheTypedTextIntoAToken() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        } withDependencies: {
            $0.mainQueue = .immediate
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.binding(.set(\.searchText, "invoice ")))

        #expect(store.state.searchTokens == [.text("invoice")])
        #expect(store.state.searchText.isEmpty)
    }

    @Test
    func freeTextNarrowsTheListToMatchingFilenames() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        } withDependencies: {
            $0.mainQueue = .immediate
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.binding(.set(\.searchText, "invoice")))

        #expect(store.state.rows.map(\.id) == [-1])
    }

    @Test
    func multipleTokensNarrowTheListTogether() async throws {
        let store = Self.searchStore()

        await store.send(.binding(.set(\.searchTokens, [.tag("tag2"), .year(1970)])))

        #expect(Set(store.state.rows.map(\.id)) == [-2, -3])
    }

    @Test
    func anEmptySearchTextShowsEveryTaggedDocument() async throws {
        let store = Self.searchStore()

        await store.send(.binding(.set(\.searchText, "")))

        #expect(store.state.rows.count == 3)
    }

    @Test
    func freeTextIgnoresCase() async throws {
        let store = Self.searchStore()

        await store.send(.binding(.set(\.searchText, "INVOICE")))
        #expect(store.state.rows.map(\.id) == [-1])

        await store.send(.binding(.set(\.searchText, "InVoIcE")))
        #expect(store.state.rows.map(\.id) == [-1])
    }

    @Test
    func aTextTokenIgnoresCase() async throws {
        let store = Self.searchStore()

        await store.send(.binding(.set(\.searchTokens, [.text("IMPORTANT")])))

        #expect(store.state.rows.map(\.id) == [-1])
    }

    @Test
    func aTypedUmlautMatchesTheSlugifiedFilename() async throws {
        let store = Self.searchStore()

        await store.send(.binding(.set(\.searchText, "büro")))
        #expect(store.state.rows.map(\.id) == [-3])

        await store.send(.binding(.set(\.searchText, "BÜRO")))
        #expect(store.state.rows.map(\.id) == [-3])
    }

    @Test
    func freeTextMatchesInTheMiddleOfAWord() async throws {
        let store = Self.searchStore()

        await store.send(.binding(.set(\.searchText, "port")))

        #expect(store.state.rows.map(\.id) == [-1])
    }

    @Test
    func spacesInTheTypedTextBecomeHyphens() async throws {
        let store = Self.searchStore()

        // A trailing space would turn the text into a token, so this stays free text.
        await store.send(.binding(.set(\.searchText, "important invoice")))

        #expect(store.state.rows.map(\.id) == [-1])
    }

    // MARK: - Document Selection Tests

    @Test
    func selectingDocumentOpensDetails() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        } withDependencies: {
            $0.mainQueue = .immediate
        }
        try await store.state.$rows.load()

        await store.send(.selectionChanged(-1)) {
            $0.$selectedDocumentId.withLock { $0 = -1 }
            $0.documentDetails = .init(document: try #require(store.state.rows.first { $0.id == -1 }).document)
        }
    }

    @Test
    func deselectingDocumentClosesDetails() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        } withDependencies: {
            $0.mainQueue = .immediate
        }
        try await store.state.$rows.load()
        await store.send(.selectionChanged(-1)) {
            $0.$selectedDocumentId.withLock { $0 = -1 }
            $0.documentDetails = .init(document: try #require(store.state.rows.first { $0.id == -1 }).document)
        }

        await store.send(.selectionChanged(nil)) {
            $0.$selectedDocumentId.withLock { $0 = nil }
            $0.documentDetails = nil
        }
    }

    /// The publisher fires while `state.premiumStatus` still holds the old value, so the action
    /// has to carry the new one.
    @Test
    func thePremiumBridgeDeliversTheNewStatus() async throws {
        let store = Self.searchStore()
        let task = await store.send(.onTask)

        // The IAP view modifier writes the shared value once StoreKit answers.
        @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .loading
        $premiumStatus.withLock { $0 = .active }

        await store.receive(\.premiumStatusChanged, .active)
        await task.cancel()
    }

    @Test
    func contentHitsAppearWhenPremiumResolvesWithoutRetyping() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try DocumentText.insert { DocumentText(rowid: -2, body: "Diese Quittung gehört zu einer Bestellung.") }.execute(db)
        }

        let store = Self.searchStore()
        await store.send(.binding(.set(\.searchText, "quittung"))).finish()
        #expect(store.state.rows.isEmpty)

        // Nothing is retyped: only the status the bridge delivered changes.
        await store.send(.premiumStatusChanged(.active)).finish()

        #expect(store.state.rows.map(\.id) == [-2])
    }

    // MARK: - Helpers

    private static func searchStore() -> TestStoreOf<ArchiveList> {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        } withDependencies: {
            $0.mainQueue = .immediate
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    // MARK: - Search State Tests

    @Test
    func searchStateChangedUpdatesState() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        } withDependencies: {
            $0.mainQueue = .immediate
        }

        await store.send(.searchStateChanged(true)) {
            $0.isSearching = true
        }

        await store.send(.searchStateChanged(false)) {
            $0.isSearching = false
        }
    }
}
