//
//  QueryTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import ArchiverDatabase

@Suite(.dependencies {
    try $0.bootstrapDatabase()
    try $0.defaultDatabase.write { db in
        try db.seed {
            Document(id: -1, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-01--invoice__bill_work.pdf"), date: seedDate(2024), specification: "invoice", tags: ["bill", "work"], isTagged: true, sizeInBytes: 10, downloadStatus: 1)
            Document(id: -2, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-02-01--receipt__bill.pdf"), date: seedDate(2024), specification: "receipt", tags: ["bill"], isTagged: true, sizeInBytes: 20, downloadStatus: 1)
            Document(id: -3, rootKey: "test", url: URL(filePath: "/Archive/2023/2023-05-01--invoice__work.pdf"), date: seedDate(2023), specification: "invoice", tags: ["work"], isTagged: true, sizeInBytes: 30, downloadStatus: 1)
            Document(id: -4, rootKey: "test", url: URL(filePath: "/Archive/untagged/scan.pdf"), date: seedDate(2024), specification: "scan", tags: [], isTagged: false, sizeInBytes: 40, downloadStatus: 0)
            DocumentTag(documentID: -1, tag: "bill")
            DocumentTag(documentID: -1, tag: "work")
            DocumentTag(documentID: -2, tag: "bill")
            DocumentTag(documentID: -3, tag: "work")
        }
    }
})
struct QueryTests {
    @Test
    func theListHoldsOnlyTaggedDocuments() async throws {
        let ids = try await Self.listIDs(tokens: [])

        #expect(Set(ids) == [-1, -2, -3])
    }

    @Test
    func aTagTokenFiltersByTag() async throws {
        #expect(Set(try await Self.listIDs(tokens: [.tag("work")])) == [-1, -3])
    }

    @Test
    func aYearTokenFiltersByTheStoredYear() async throws {
        #expect(Set(try await Self.listIDs(tokens: [.year(2023)])) == [-3])
    }

    @Test
    func aTextTokenMatchesTheFilename() async throws {
        #expect(Set(try await Self.listIDs(tokens: [.text("receipt")])) == [-2])
    }

    @Test
    func tokensCombineWithAnd() async throws {
        #expect(try await Self.listIDs(tokens: [.tag("work"), .year(2024)]) == [-1])
    }

    @Test
    func aTextTokenTreatsWildcardsLiterally() async throws {
        // A raw `%` would otherwise match every filename.
        #expect(try await Self.listIDs(tokens: [.text("%")]).isEmpty)
    }

    @Test
    func theListIsNeverCapped() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            let extras = (1...250).map { index in
                Document(id: -1000 - index, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-01--bulk\(index)__bill.pdf"), date: seedDate(2024), specification: "bulk\(index)", tags: ["bill"], isTagged: true, sizeInBytes: 1, downloadStatus: 1)
            }
            try Document.insert { extras }.execute(db)
        }

        #expect(try await Self.listIDs(tokens: []).count == 253)
    }

    @Test
    func tagCountsAreOrderedByUsage() async throws {
        @Dependency(\.defaultDatabase) var database
        let usage = try await database.read { db in
            try DocumentTag.counts(limit: 10).fetchAll(db)
        }

        #expect(usage.map(\.tag) == ["bill", "work"])
        #expect(usage.map(\.count) == [2, 2])
    }

    @Test
    func tagCountsCanBeNarrowedToAPrefix() async throws {
        @Dependency(\.defaultDatabase) var database
        let usage = try await database.read { db in
            try DocumentTag.counts(prefix: "wo", limit: 10).fetchAll(db)
        }

        #expect(usage.map(\.tag) == ["work"])
    }

    @Test
    func cooccurringTagsExcludeTheGivenOnes() async throws {
        @Dependency(\.defaultDatabase) var database
        let usage = try await database.read { db in
            try DocumentTag.cooccurring(with: ["bill"], limit: 10).fetchAll(db)
        }

        #expect(usage.map(\.tag) == ["work"])
    }

    @Test
    func yearCountsCanExcludeTheInbox() async throws {
        @Dependency(\.defaultDatabase) var database
        let all = try await database.read { db in
            try Document.yearCounts(taggedOnly: false).fetchAll(db)
        }
        let taggedOnly = try await database.read { db in
            try Document.yearCounts(taggedOnly: true).fetchAll(db)
        }

        #expect(all.first { $0.year == 2024 }?.count == 3)
        #expect(taggedOnly.first { $0.year == 2024 }?.count == 2)
    }

    @Test
    func theUntaggedCountCountsTheInbox() async throws {
        @Dependency(\.defaultDatabase) var database
        let count = try await database.read { db in
            try Document.untaggedCount.fetchOne(db)
        }

        #expect(count == 1)
    }

    // MARK: - Helpers

    private static func listIDs(tokens: [SearchToken]) async throws -> [Document.ID] {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try Document.list(tokens: tokens).fetchAll(db).map(\.id)
        }
    }
}

private func seedDate(_ year: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar.date(from: DateComponents(year: year, month: 6, day: 1)) ?? .distantPast
}
