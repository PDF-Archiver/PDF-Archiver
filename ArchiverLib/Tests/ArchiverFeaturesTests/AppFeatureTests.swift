import ArchiverModels
import ComposableArchitecture
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct AppFeatureTests {
    @Test
    func deleteUntaggedDocument() async throws {
        let currentYear = Calendar.current.component(.year, from: Date())
        let document1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let document2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: true)
        let document3 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: true)
        let document4 = Document.mock(url: URL(string: "https://example.com/4")!, isTagged: false)
        let document5 = Document.mock(url: URL(string: "https://example.com/5")!, isTagged: false)
        let document6 = Document.mock(url: URL(string: "https://example.com/6")!, isTagged: false)
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

    @Test
    func deleteTaggedDocument() async throws {
        let currentYear = Calendar.current.component(.year, from: Date())
        let document1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let document2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: true)
        let document3 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: true)
        let document4 = Document.mock(url: URL(string: "https://example.com/4")!, isTagged: false)
        let document5 = Document.mock(url: URL(string: "https://example.com/5")!, isTagged: false)
        let document6 = Document.mock(url: URL(string: "https://example.com/6")!, isTagged: false)
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
