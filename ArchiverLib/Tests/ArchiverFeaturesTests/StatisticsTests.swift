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
            Document(id: -1, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-01--invoice__invoice_work.pdf"), date: statisticsDate(2024), specification: "invoice", tags: ["invoice", "work"], isTagged: true, sizeInBytes: 1000, downloadStatus: 1)
            Document(id: -2, rootKey: "test", url: URL(filePath: "/Archive/2023/2023-01-01--receipt__invoice.pdf"), date: statisticsDate(2023), specification: "receipt", tags: ["invoice"], isTagged: true, sizeInBytes: 2000, downloadStatus: 1)
            Document(id: -3, rootKey: "test", url: URL(filePath: "/Archive/untagged/scan.pdf"), date: statisticsDate(2024), specification: "scan", tags: [], isTagged: false, sizeInBytes: 3000, downloadStatus: 1)
            DocumentTag(documentID: -1, tag: "invoice")
            DocumentTag(documentID: -1, tag: "work")
            DocumentTag(documentID: -2, tag: "invoice")
        }
    }
})
struct StatisticsTests {
    @Test
    func everyFigureComesFromTheDatabase() async throws {
        let state = Statistics.State()
        try await state.$stats.load()

        #expect(state.stats.totalDocuments == 3)
        #expect(state.stats.untaggedDocuments == 1)
        #expect(state.stats.totalBytes == 6000)
        #expect(state.totalStorageSize.value == 6000)
    }

    @Test
    func yearsCountEveryDocumentIncludingTheInbox() async throws {
        let state = Statistics.State()
        try await state.$stats.load()

        #expect(state.stats.yearStats == [2024: 2, 2023: 1])
    }

    @Test
    func topTagsAreOrderedByUsage() async throws {
        let state = Statistics.State()
        try await state.$stats.load()

        #expect(state.stats.topTags == [TagCount(tag: "invoice", count: 2), TagCount(tag: "work", count: 1)])
    }

    @Test
    func anEmptyArchiveReportsZeroes() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try Document.delete().execute(db)
        }

        let state = Statistics.State()
        try await state.$stats.load()

        #expect(state.stats.totalDocuments == 0)
        #expect(state.stats.totalBytes == 0)
        #expect(state.stats.yearStats.isEmpty)
        #expect(state.stats.topTags.isEmpty)
    }

    @Test
    func onTaskLoadsTheFigures() async throws {
        let store = TestStore(initialState: Statistics.State()) {
            Statistics()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onTask)

        #expect(store.state.stats.totalDocuments == 3)
    }
}

private func statisticsDate(_ year: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar.date(from: DateComponents(year: year, month: 6, day: 1)) ?? .distantPast
}
