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
    try $0.bootstrapDatabase()
    try $0.defaultDatabase.write { db in
        try db.seed {
            Document(id: -1, rootKey: "test", url: URL(filePath: "/Archive/untagged/scan1.pdf"), date: Date(timeIntervalSince1970: 100), specification: "scan1", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
            Document(id: -2, rootKey: "test", url: URL(filePath: "/Archive/untagged/scan2.pdf"), date: Date(timeIntervalSince1970: 200), specification: "scan2", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
            Document(id: -3, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-01--filed__tag.pdf"), date: Date(timeIntervalSince1970: 300), specification: "filed", tags: ["tag"], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
        }
    }
})
struct UntaggedDocumentListTests {
    // MARK: - Inbox Query Tests

    @Test
    func theInboxHoldsOnlyUntaggedDocuments() async throws {
        let state = UntaggedDocumentList.State()
        try await state.$documents.load()

        #expect(state.documents.map(\.id) == [-2, -1])
    }

    @Test
    func theInboxIsEmptyOnceEveryDocumentIsTagged() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try Document.where { !$0.isTagged }.update { $0.isTagged = true }.execute(db)
        }

        let state = UntaggedDocumentList.State()
        try await state.$documents.load()

        #expect(state.documents.isEmpty)
    }

    @Test
    func theInboxRefreshesWhenADocumentIsFiled() async throws {
        @Dependency(\.defaultDatabase) var database
        let state = UntaggedDocumentList.State()
        try await state.$documents.load()
        #expect(state.documents.count == 2)

        try await database.write { db in
            try Document.find(-1).update { $0.isTagged = true }.execute(db)
        }
        try await Task.sleep(for: .milliseconds(500))

        #expect(state.documents.map(\.id) == [-2])
    }

    // MARK: - Document Selection Tests

    @Test
    func selectingDocumentOpensDetails() async throws {
        let store = TestStore(initialState: UntaggedDocumentList.State()) {
            UntaggedDocumentList()
        }
        try await store.state.$documents.load()
        let document = try #require(store.state.documents.first { $0.id == -1 })

        await store.send(.selectionChanged(-1)) {
            $0.$selectedDocumentId.withLock { $0 = -1 }
            $0.documentDetails = .init(document: document)
        }

        await store.receive(\.documentDetails.presented.updateShowInspector) {
            $0.documentDetails?.showInspector = true
        }

        #expect(store.state.documentDetails?.document.id == -1)
    }

    @Test
    func deselectingDocumentClosesDetails() async throws {
        let store = TestStore(initialState: UntaggedDocumentList.State()) {
            UntaggedDocumentList()
        }
        try await store.state.$documents.load()
        let document = try #require(store.state.documents.first { $0.id == -1 })

        await store.send(.selectionChanged(-1)) {
            $0.$selectedDocumentId.withLock { $0 = -1 }
            $0.documentDetails = .init(document: document)
        }
        await store.receive(\.documentDetails.presented.updateShowInspector) {
            $0.documentDetails?.showInspector = true
        }

        await store.send(.selectionChanged(nil)) {
            $0.$selectedDocumentId.withLock { $0 = nil }
            $0.documentDetails = nil
        }
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
    func premiumStatusStartsLoading() throws {
        let state = UntaggedDocumentList.State()

        #expect(state.premiumStatus == .loading)
    }

    // MARK: - Document Details Tests

    @Test
    func documentDetailsNilWhenNotSelected() throws {
        let state = UntaggedDocumentList.State()

        #expect(state.documentDetails == nil)
    }
}
