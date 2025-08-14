import ArchiverModels
import ComposableArchitecture
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct AppFeatureTests {
    @Test
    func deleteUntaggedDocument() async throws {
        
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let document1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let document2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: true)
        let document3 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: true)
        let document4 = Document.mock(url: URL(string: "https://example.com/4")!, isTagged: false)
        let document5 = Document.mock(url: URL(string: "https://example.com/5")!, isTagged: false)
        let document6 = Document.mock(url: URL(string: "https://example.com/6")!, isTagged: false)
        await store.send(.documentsChanged([document1, document2, document3, document4, document5, document6])) {
            $0.$documents.withLock { $0 = [document6, document5, document4, document3, document2, document1] }
            $0.untaggedDocumentsCount = 3
            $0.tabYearSuggestions = [currentYear]
            $0.archiveList.searchSuggestedTokens = [.year(currentYear)]
        }
        
//        await store.send(.untaggedDocumentList(.documentDetails(.presented(.delegate(.deleteDocument(document5))))))

    }

    @Test
    func deleteTaggedDocument() async throws {

    }
}
