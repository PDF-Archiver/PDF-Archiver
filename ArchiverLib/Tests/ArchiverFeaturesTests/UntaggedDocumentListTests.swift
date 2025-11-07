import ArchiverModels
import ComposableArchitecture
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct UntaggedDocumentListTests {
    // MARK: - Document Selection Tests

    @Test
    func selectingDocumentOpensDetails() async throws {
        // swiftlint:disable force_unwrapping
        let document = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        let store = TestStore(initialState: UntaggedDocumentList.State(documents: [document])) {
            UntaggedDocumentList()
        }

        await store.send(.binding(.set(\.selectedDocumentId, document.id))) {
            $0.$selectedDocumentId.withLock { $0 = document.id }
            $0.documentDetails = .init(document: Shared(value: document))
        }
    }

    @Test
    func deselectingDocumentClosesDetails() async throws {
        // swiftlint:disable force_unwrapping
        let document = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        let store = TestStore(initialState: UntaggedDocumentList.State(
            documents: [document],
            selectedDocumentId: Shared(value: document.id),
            documentDetails: .init(document: Shared(value: document))
        )) {
            UntaggedDocumentList()
        }

        await store.send(.binding(.set(\.selectedDocumentId, nil))) {
            $0.$selectedDocumentId.withLock { $0 = nil }
            $0.documentDetails = nil
        }
    }

    // MARK: - Untagged Documents Filter Tests

    @Test
    func untaggedDocumentsFilter() async throws {
        // swiftlint:disable force_unwrapping
        let taggedDoc = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let untaggedDoc1 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: false)
        let untaggedDoc2 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        let state = UntaggedDocumentList.State(documents: [taggedDoc, untaggedDoc1, untaggedDoc2])

        #expect(state.untaggedDocuments.count == 2)
        #expect(state.untaggedDocuments.contains(where: { $0.id == untaggedDoc1.id }))
        #expect(state.untaggedDocuments.contains(where: { $0.id == untaggedDoc2.id }))
        #expect(!state.untaggedDocuments.contains(where: { $0.id == taggedDoc.id }))
    }

    @Test
    func emptyUntaggedDocuments() async throws {
        // swiftlint:disable force_unwrapping
        let taggedDoc1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let taggedDoc2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: true)
        // swiftlint:enable force_unwrapping

        let state = UntaggedDocumentList.State(documents: [taggedDoc1, taggedDoc2])

        #expect(state.untaggedDocuments.isEmpty)
    }

    // MARK: - Delegate Tests

    @Test
    func onCancelIapButtonTapped() async throws {
        let store = TestStore(initialState: UntaggedDocumentList.State()) {
            UntaggedDocumentList()
        }

        await store.send(.delegate(.onCancelIapButtonTapped))
    }

    // MARK: - Premium Status Tests

    @Test
    func premiumStatusInactive() async throws {
        let state = UntaggedDocumentList.State(premiumStatus: Shared(value: .inactive))
        #expect(state.premiumStatus == .inactive)
    }

    @Test
    func premiumStatusActive() async throws {
        let state = UntaggedDocumentList.State(premiumStatus: Shared(value: .active))
        #expect(state.premiumStatus == .active)
    }

    // MARK: - Document Details Tests

    @Test
    func documentDetailsNotNilWhenSelected() async throws {
        // swiftlint:disable force_unwrapping
        let document = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        let state = UntaggedDocumentList.State(
            documents: [document],
            selectedDocumentId: Shared(value: document.id),
            documentDetails: .init(document: Shared(value: document))
        )

        #expect(state.documentDetails != nil)
        #expect(state.documentDetails?.document.wrappedValue.id == document.id)
    }

    @Test
    func documentDetailsNilWhenNotSelected() async throws {
        let state = UntaggedDocumentList.State()

        #expect(state.documentDetails == nil)
    }

    // MARK: - Multiple Document Tests

    @Test
    func multipleUntaggedDocuments() async throws {
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: false)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: false)
        let doc3 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        let state = UntaggedDocumentList.State(documents: [doc1, doc2, doc3])

        #expect(state.untaggedDocuments.count == 3)
    }

    // MARK: - State Update Tests

    @Test
    func stateUpdatesOnDocumentChange() async throws {
        // swiftlint:disable force_unwrapping
        let initialDoc = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        let store = TestStore(initialState: UntaggedDocumentList.State(documents: [initialDoc])) {
            UntaggedDocumentList()
        }

        #expect(store.state.untaggedDocuments.count == 1)

        // swiftlint:disable force_unwrapping
        let newDoc = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        await store.send(.binding(.set(\.documents, [initialDoc, newDoc]))) {
            $0.$documents.withLock { $0 = [initialDoc, newDoc] }
        }

        #expect(store.state.untaggedDocuments.count == 2)
    }
}
