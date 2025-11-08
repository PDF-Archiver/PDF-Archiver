import ArchiverModels
import ComposableArchitecture
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct ArchiveListTests {
    // MARK: - Search Token Tests

    @Test
    func addingTagSearchToken() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        }

        await store.send(.binding(.set(\.searchTokens, [.tag("invoice")]))) {
            $0.searchTokens = [.tag("invoice")]
        }
    }

    @Test
    func addingYearSearchToken() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        }

        await store.send(.binding(.set(\.searchTokens, [.year(2024)]))) {
            $0.searchTokens = [.year(2024)]
        }
    }

    @Test
    func addingMultipleSearchTokens() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        }

        await store.send(.binding(.set(\.searchTokens, [.tag("invoice"), .year(2024)]))) {
            $0.searchTokens = [.tag("invoice"), .year(2024)]
        }
    }

    // MARK: - Search Query Tests

    @Test
    func searchTextFiltersDocuments() async throws {
        let doc1 = Document.mock(
            url: URL(fileURLWithPath: "/tmp/2024-01-01--invoice__tag1.pdf"),
            specification: "invoice",
            isTagged: true
        )
        let doc2 = Document.mock(
            url: URL(fileURLWithPath: "/tmp/2024-01-01--receipt__tag1.pdf"),
            specification: "receipt",
            isTagged: true
        )

        let state = ArchiveList.State(documents: [doc1, doc2], searchText: "invoice")

        #expect(state.filteredDocuments.count == 1)
        #expect(state.filteredDocuments.first?.id == doc1.id)
    }

    @Test
    func emptySearchTextShowsAllDocuments() async throws {
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: true)
        // swiftlint:enable force_unwrapping

        let state = ArchiveList.State(documents: [doc1, doc2], searchText: "")

        #expect(state.filteredDocuments.count == 2)
    }

    // MARK: - Document Selection Tests

    @Test
    func selectingDocumentOpensDetails() async throws {
        // swiftlint:disable force_unwrapping
        let document = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        // swiftlint:enable force_unwrapping

        let store = TestStore(initialState: ArchiveList.State(documents: [document])) {
            ArchiveList()
        }

        await store.send(.binding(.set(\.selectedDocumentId, document.id))) {
            $0.$selectedDocumentId.withLock { $0 = document.id }
            $0.documentDetails = .init(document: Shared(value: document))
        }
    }

    @Test
    func deselectingDocumentClosesDetails() async throws {
        // swiftlint:disable force_unwrapping
        let document = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        // swiftlint:enable force_unwrapping

        let store = TestStore(initialState: ArchiveList.State(
            documents: [document],
            selectedDocumentId: Shared(value: document.id),
            documentDetails: .init(document: Shared(value: document))
        )) {
            ArchiveList()
        }

        await store.send(.binding(.set(\.selectedDocumentId, nil))) {
            $0.$selectedDocumentId.withLock { $0 = nil }
            $0.documentDetails = nil
        }
    }

    // MARK: - Filtered Documents Tests

    @Test
    func filteredDocumentsByTag() async throws {
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(
            url: URL(string: "https://example.com/1")!,
            tags: ["invoice"],
            isTagged: true
        )
        let doc2 = Document.mock(
            url: URL(string: "https://example.com/2")!,
            tags: ["receipt"],
            isTagged: true
        )
        let doc3 = Document.mock(
            url: URL(string: "https://example.com/3")!,
            tags: ["invoice", "work"],
            isTagged: true
        )
        // swiftlint:enable force_unwrapping

        let state = ArchiveList.State(
            documents: [doc1, doc2, doc3],
            searchTokens: [.tag("invoice")]
        )

        #expect(state.filteredDocuments.count == 2)
        #expect(state.filteredDocuments.contains(where: { $0.id == doc1.id }))
        #expect(state.filteredDocuments.contains(where: { $0.id == doc3.id }))
    }

    @Test
    func filteredDocumentsByYear() async throws {
        let calendar = Calendar.current
        // swiftlint:disable force_unwrapping
        let date2024 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let date2023 = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1))!

        let doc1 = Document.mock(
            url: URL(fileURLWithPath: "/tmp/2024-01-01--document__tag1.pdf"),
            date: date2024,
            isTagged: true
        )
        let doc2 = Document.mock(
            url: URL(fileURLWithPath: "/tmp/2023-01-01--document__tag1.pdf"),
            date: date2023,
            isTagged: true
        )
        // swiftlint:enable force_unwrapping

        let state = ArchiveList.State(
            documents: [doc1, doc2],
            searchTokens: [.year(2024)]
        )

        #expect(state.filteredDocuments.count == 1)
        #expect(state.filteredDocuments.first?.id == doc1.id)
    }

    @Test
    func filteredDocumentsByMultipleTokens() async throws {
        let calendar = Calendar.current
        // swiftlint:disable:next force_unwrapping
        let date2024 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

        let doc1 = Document.mock(
            url: URL(fileURLWithPath: "/tmp/2024-01-01--document__invoice.pdf"),
            date: date2024,
            tags: ["invoice"],
            isTagged: true
        )
        let doc2 = Document.mock(
            url: URL(fileURLWithPath: "/tmp/2024-01-01--document__receipt.pdf"),
            date: date2024,
            tags: ["receipt"],
            isTagged: true
        )
        let doc3 = Document.mock(
            url: URL(fileURLWithPath: "/tmp/2025-01-01--document__invoice.pdf"),
            date: Date(),
            tags: ["invoice"],
            isTagged: true
        )

        let state = ArchiveList.State(
            documents: [doc1, doc2, doc3],
            searchTokens: [.tag("invoice"), .year(2024)]
        )

        #expect(state.filteredDocuments.count == 1)
        #expect(state.filteredDocuments.first?.id == doc1.id)
    }

    // MARK: - Search State Tests

    @Test
    func isSearchingState() async throws {
        let store = TestStore(initialState: ArchiveList.State()) {
            ArchiveList()
        }

        await store.send(.binding(.set(\.isSearching, true))) {
            $0.isSearching = true
        }

        await store.send(.binding(.set(\.isSearching, false))) {
            $0.isSearching = false
        }
    }

    // MARK: - Document Count Tests

    @Test
    func documentCount() async throws {
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!, isTagged: true)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: true)
        let doc3 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: true)
        // swiftlint:enable force_unwrapping

        let state = ArchiveList.State(documents: [doc1, doc2, doc3])

        #expect(state.filteredDocuments.count == 3)
    }
}
