import ArchiverModels
import ComposableArchitecture
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct AppFeatureTests {
    // MARK: - Tab Selection Tests

    @Test
    func tabSelectionUpdatesSearchTokens() async throws {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        // Switch to tags tab
        await store.send(.binding(.set(\.selectedTab, .sectionTags("invoice")))) {
            $0.selectedTab = .sectionTags("invoice")
            $0.archiveList.searchTokens = [.tag("invoice")]
            $0.archiveList.$selectedDocumentId.withLock { $0 = nil }
        }

        // Switch to years tab
        await store.send(.binding(.set(\.selectedTab, .sectionYears(2024)))) {
            $0.selectedTab = .sectionYears(2024)
            $0.archiveList.searchTokens = [.year(2024)]
            $0.archiveList.$selectedDocumentId.withLock { $0 = nil }
        }

        // Switch back to search clears tokens
        await store.send(.binding(.set(\.selectedTab, .search))) {
            $0.selectedTab = .search
            $0.archiveList.searchTokens = []
            $0.archiveList.$selectedDocumentId.withLock { $0 = nil }
        }
    }

    @Test
    func tabSelectionClearsSelectedDocument() async throws {
        // swiftlint:disable force_unwrapping
        let document = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        // swiftlint:enable force_unwrapping

        let store = TestStore(initialState: AppFeature.State(
            archiveList: ArchiveList.State(
                documents: [document],
                selectedDocumentId: Shared(value: document.id)
            )
        )) {
            AppFeature()
        }

        await store.send(.binding(.set(\.selectedTab, .inbox))) {
            $0.selectedTab = .inbox
            $0.archiveList.$selectedDocumentId.withLock { $0 = nil }
        }
    }

    // MARK: - Documents Changed Tests

    @Test
    func documentsChangedSortsAndUpdates() async throws {
        let currentYear = Calendar.current.component(.year, from: Date())
        // swiftlint:disable force_unwrapping
        let document1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let document2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: true)
        let document3 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.widgetStore.updateWidgetWith = { _ in }
            $0.archiveStore.startDownloadOf = { _ in }
        }

        await store.send(.documentsChanged([document1, document2, document3])) {
            $0.$documents.withLock { $0 = [document3, document2, document1] }
            $0.untaggedDocumentsCount = 1
            $0.tabYearSuggestions = [currentYear]
            $0.archiveList.searchSuggestedTokens = [.year(currentYear)]
        }

        await store.receive(\.prefetchDocuments)
        await store.receive(\.updateWidget)
    }

    @Test
    func documentsChangedCreatesTagSuggestions() async throws {
        let currentYear = Calendar.current.component(.year, from: Date())
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!, tags: ["invoice", "work"], isTagged: true)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!, tags: ["invoice", "personal"], isTagged: true)
        let doc3 = Document.mock(url: URL(string: "https://example.com/3")!, tags: ["invoice"], isTagged: true)
        // swiftlint:enable force_unwrapping

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.widgetStore.updateWidgetWith = { _ in }
            $0.archiveStore.startDownloadOf = { _ in }
        }

        await store.send(.documentsChanged([doc1, doc2, doc3])) {
            $0.$documents.withLock { $0 = [doc3, doc2, doc1] }
            $0.untaggedDocumentsCount = 0
            $0.tabTagSuggestions = ["invoice", "personal", "work"]
            $0.tabYearSuggestions = [currentYear]
            $0.archiveList.searchSuggestedTokens = [.tag("invoice"), .tag("personal"), .tag("work"), .year(currentYear)]
        }

        await store.receive(\.prefetchDocuments)
        await store.receive(\.updateWidget)
    }

    @Test
    func documentsChangedCreatesYearSuggestions() async throws {
        let calendar = Calendar.current
        let date2024 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let date2023 = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1))!
        let date2022 = calendar.date(from: DateComponents(year: 2022, month: 1, day: 1))!

        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!, date: date2024, isTagged: true)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!, date: date2023, isTagged: true)
        let doc3 = Document.mock(url: URL(string: "https://example.com/3")!, date: date2022, isTagged: true)
        // swiftlint:enable force_unwrapping

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.widgetStore.updateWidgetWith = { _ in }
            $0.archiveStore.startDownloadOf = { _ in }
        }

        await store.send(.documentsChanged([doc1, doc2, doc3])) {
            $0.$documents.withLock { $0 = [doc1, doc2, doc3] }
            $0.tabYearSuggestions = [2024, 2023, 2022]
            $0.archiveList.searchSuggestedTokens = [.year(2024), .year(2023), .year(2022)]
        }

        await store.receive(\.prefetchDocuments)
        await store.receive(\.updateWidget)
    }

    // MARK: - Scene Phase Tests

    @Test
    func scenePhaseActiveReloadsDocuments() async throws {
        let store = TestStore(initialState: AppFeature.State(isDocumentLoading: false)) {
            AppFeature()
        } withDependencies: {
            $0.documentProcessor.triggerFolderObservation = { }
            $0.archiveStore.reloadDocuments = { }
        }

        await store.send(.onScenePhaseChanged(old: .background, new: .active))
    }

    @Test
    func scenePhaseDoesNotReloadWhileLoading() async throws {
        let store = TestStore(initialState: AppFeature.State(isDocumentLoading: true)) {
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

    // MARK: - Loading State Tests

    @Test
    func isLoadingChangedUpdatesState() async throws {
        let store = TestStore(initialState: AppFeature.State(isDocumentLoading: false)) {
            AppFeature()
        }

        await store.send(.isLoadingChanged(true)) {
            $0.isDocumentLoading = true
        }

        await store.send(.isLoadingChanged(false)) {
            $0.isDocumentLoading = false
        }
    }

    // MARK: - Delete Document Tests

    @Test(.disabled("Currently not working"))
    func deleteUntaggedDocument() async throws {
        let currentYear = Calendar.current.component(.year, from: Date())
        // swiftlint:disable force_unwrapping
        let document1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let document2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: true)
        let document3 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: true)
        let document4 = Document.mock(url: URL(string: "https://example.com/4")!, isTagged: false)
        let document5 = Document.mock(url: URL(string: "https://example.com/5")!, isTagged: false)
        let document6 = Document.mock(url: URL(string: "https://example.com/6")!, isTagged: false)
        // swiftlint:enable force_unwrapping
        let documents = IdentifiedArrayOf(uniqueElements: [document1, document2, document3, document4, document5, document6])

        let store = TestStore(initialState: AppFeature.State(documents: documents,
                                                             untaggedDocumentList: UntaggedDocumentList.State(documents: documents,
                                                                                                              selectedDocumentId: Shared(value: document6.id),
                                                                                                              documentDetails: .init(document: Shared(value: document6))))) {
            AppFeature()
        } withDependencies: {
            $0.archiveStore.deleteDocumentAt = { _ in }
        }

        await store.send(.documentsChanged([document1, document2, document3, document4, document5, document6])) {
            $0.$documents.withLock { $0 = [document6, document5, document4, document3, document2, document1] }
            $0.untaggedDocumentsCount = 3
            $0.tabYearSuggestions = [currentYear]
            $0.archiveList.searchSuggestedTokens = [.year(currentYear)]
        }

        await store.send(.binding(.set(\.selectedTab, .inbox))) {
            $0.selectedTab = .inbox
        }

        await store.send(.untaggedDocumentList(.documentDetails(.presented(.delegate(.deleteDocument(document5)))))) {
            $0.untaggedDocumentList.$documents.withLock { $0 = [document6, document4, document3, document2, document1] }

            // select the next document
            $0.untaggedDocumentList.$selectedDocumentId.withLock { $0 = document6.id }

            // show the next document in the details
            $0.untaggedDocumentList.documentDetails = .init(document: Shared(value: document6))
        }
    }

    @Test(.disabled("Currently not working"))
    func deleteTaggedDocument() async throws {
        let currentYear = Calendar.current.component(.year, from: Date())
        // swiftlint:disable force_unwrapping
        let document1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let document2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: true)
        let document3 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: true)
        let document4 = Document.mock(url: URL(string: "https://example.com/4")!, isTagged: false)
        let document5 = Document.mock(url: URL(string: "https://example.com/5")!, isTagged: false)
        let document6 = Document.mock(url: URL(string: "https://example.com/6")!, isTagged: false)
        // swiftlint:enable force_unwrapping
        let documents = IdentifiedArrayOf(uniqueElements: [document1, document2, document3, document4, document5, document6])

        let store = TestStore(initialState: AppFeature.State(documents: documents,
                                                             archiveList: ArchiveList.State(documents: documents,
                                                                                            selectedDocumentId: Shared(value: document6.id),
                                                                                            documentDetails: .init(document: Shared(value: document6))))) {
            AppFeature()
        } withDependencies: {
            $0.archiveStore.deleteDocumentAt = { _ in }
        }

        await store.send(.documentsChanged([document1, document2, document3, document4, document5, document6])) {
            $0.$documents.withLock { $0 = [document6, document5, document4, document3, document2, document1] }
            $0.untaggedDocumentsCount = 3
            $0.tabYearSuggestions = [currentYear]
            $0.archiveList.searchSuggestedTokens = [.year(currentYear)]
        }

        await store.send(.binding(.set(\.selectedTab, .search)))

        await store.send(.archiveList(.documentDetails(.presented(.delegate(.deleteDocument(document2)))))) {
            $0.archiveList.$documents.withLock { $0 = [document6, document5, document4, document3, document1] }

            // select the next document
            $0.archiveList.$selectedDocumentId.withLock { $0 = document3.id }

            // show the next document in the details
            $0.archiveList.documentDetails = .init(document: Shared(value: document3))
        }
    }
}
