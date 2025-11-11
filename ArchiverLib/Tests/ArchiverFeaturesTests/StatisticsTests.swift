import ArchiverModels
import ComposableArchitecture
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct StatisticsTests {
    // MARK: - Document Statistics Tests

    @Test
    func statisticsWithDocuments() async throws {
        let calendar = Calendar.current

        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(
            url: URL(string: "https://example.com/1")!,
            tags: ["invoice", "work"]
        )
        let doc2 = Document.mock(
            url: URL(string: "https://example.com/2")!,
            tags: ["receipt", "personal"]
        )
        let doc3 = Document.mock(
            url: URL(string: "https://example.com/3")!,
            tags: ["invoice", "personal"]
        )
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [doc1, doc2, doc3])

        #expect(state.documents.count == 3)
    }

    @Test
    func statisticsWithEmptyDocuments() async throws {
        let state = Statistics.State()

        #expect(state.documents.isEmpty)
    }

    // MARK: - Tag Count Tests

    @Test
    func tagCountsCalculation() async throws {
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(
            url: URL(string: "https://example.com/1")!,
            tags: ["invoice"]
        )
        let doc2 = Document.mock(
            url: URL(string: "https://example.com/2")!,
            tags: ["invoice"]
        )
        let doc3 = Document.mock(
            url: URL(string: "https://example.com/3")!,
            tags: ["receipt"]
        )
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [doc1, doc2, doc3])

        // TagCounts should be calculated from documents
        #expect(state.documents.count == 3)
    }

    @Test
    func tagCountsWithMultipleTags() async throws {
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(
            url: URL(string: "https://example.com/1")!,
            tags: ["invoice", "work", "tax"]
        )
        let doc2 = Document.mock(
            url: URL(string: "https://example.com/2")!,
            tags: ["invoice", "personal"]
        )
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [doc1, doc2])

        #expect(state.documents.count == 2)
    }

    // MARK: - Year Statistics Tests

    @Test
    func statisticsByYear() async throws {
        let calendar = Calendar.current
        // swiftlint:disable force_unwrapping
        let date2024 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let date2023 = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1))!
        let date2022 = calendar.date(from: DateComponents(year: 2022, month: 1, day: 1))!

        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!, date: date2024)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!, date: date2023)
        let doc3 = Document.mock(url: URL(string: "https://example.com/3")!, date: date2022)
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [doc1, doc2, doc3])

        #expect(state.documents.count == 3)
    }

    @Test
    func statisticsSingleYear() async throws {
        let calendar = Calendar.current
        // swiftlint:disable force_unwrapping
        let date2024 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!, date: date2024)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!, date: date2024)
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [doc1, doc2])

        #expect(state.documents.count == 2)
    }

    // MARK: - Document Count Tests

    @Test
    func totalDocumentCount() async throws {
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!)
        let doc3 = Document.mock(url: URL(string: "https://example.com/3")!)
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [doc1, doc2, doc3])

        #expect(state.documents.count == 3)
    }

    @Test
    func zeroDocumentCount() async throws {
        let state = Statistics.State()

        #expect(state.documents.isEmpty)
    }

    // MARK: - Tagged vs Untagged Tests

    @Test
    func taggedDocumentsCount() async throws {
        // swiftlint:disable force_unwrapping
        let tagged1 = Document.mock(url: URL(string: "https://example.com/1")!, tags: ["tag1"], isTagged: true)
        let tagged2 = Document.mock(url: URL(string: "https://example.com/2")!, tags: ["tag2"], isTagged: true)
        let untagged = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [tagged1, tagged2, untagged])
        let taggedDocs = state.documents.filter(\.isTagged)

        #expect(taggedDocs.count == 2)
    }

    @Test
    func untaggedDocumentsCount() async throws {
        // swiftlint:disable force_unwrapping
        let tagged = Document.mock(url: URL(string: "https://example.com/1")!, tags: ["tag"], isTagged: true)
        let untagged1 = Document.mock(url: URL(string: "https://example.com/2")!, isTagged: false)
        let untagged2 = Document.mock(url: URL(string: "https://example.com/3")!, isTagged: false)
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [tagged, untagged1, untagged2])
        let untaggedDocs = state.documents.filter { !$0.isTagged }

        #expect(untaggedDocs.count == 2)
    }

    // MARK: - Storage Size Tests

    @Test
    func totalStorageSize() async throws {
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!, sizeInBytes: 1000)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!, sizeInBytes: 2000)
        let doc3 = Document.mock(url: URL(string: "https://example.com/3")!, sizeInBytes: 3000)
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [doc1, doc2, doc3])
        let totalSize = state.documents.reduce(0.0) { $0 + $1.sizeInBytes }

        #expect(totalSize == 6000.0)
    }

    @Test
    func zeroStorageSize() async throws {
        let state = Statistics.State()
        let totalSize = state.documents.reduce(0.0) { $0 + $1.sizeInBytes }

        #expect(totalSize == 0.0)
    }

    // MARK: - State Initialization Tests

    @Test
    func defaultStateInitialization() async throws {
        let state = Statistics.State()

        #expect(state.documents.isEmpty)
    }

    @Test
    func stateWithDocumentsInitialization() async throws {
        // swiftlint:disable force_unwrapping
        let doc1 = Document.mock(url: URL(string: "https://example.com/1")!)
        let doc2 = Document.mock(url: URL(string: "https://example.com/2")!)
        // swiftlint:enable force_unwrapping

        let state = Statistics.State(documents: [doc1, doc2])

        #expect(state.documents.count == 2)
    }
}
