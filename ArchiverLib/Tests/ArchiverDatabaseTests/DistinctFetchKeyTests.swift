//
//  DistinctFetchKeyTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 01.10.26.
//

import ArchiverModels
import Combine
import Dependencies
import DependenciesTestSupport
import Foundation
import Sharing
import SQLiteData
import Synchronization
import Testing

@testable import ArchiverDatabase

@Suite(.dependencies {
    try $0.bootstrapDatabase()
    try $0.defaultDatabase.write { db in
        try db.seed {
            Document(id: -1, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-01--invoice__bill.pdf"), date: Date(timeIntervalSince1970: 0), specification: "invoice", tags: ["bill"], isTagged: true, sizeInBytes: 10, downloadStatus: 0)
        }
    }
})
struct DistinctFetchKeyTests {
    @Test
    func aWriteThatLeavesTheRowsEqualIsNotPublished() async throws {
        @Dependency(\.defaultDatabase) var database
        let published = try await Self.specificationsPublished {
            try await database.write { db in
                try Document.find(-1).update { $0.specification = "invoice" }.execute(db)
            }
        }

        #expect(published == [["invoice"], ["receipt"]])
    }

    @Test
    func aChangeTheListDoesNotShowIsNotPublished() async throws {
        @Dependency(\.defaultDatabase) var database
        let published = try await Self.specificationsPublished {
            try await database.write { db in
                try Document.find(-1).update {
                    $0.downloadStatus = 1
                    $0.sizeInBytes = 20
                }
                .execute(db)
            }
        }

        #expect(published == [["invoice"], ["receipt"]])
    }

    /// Runs `write`, then renames the document to "receipt" and waits for that to arrive, so
    /// anything `write` published is already recorded by then.
    private static func specificationsPublished(after write: () async throws -> Void) async throws -> [[String]] {
        @Dependency(\.defaultDatabase) var database
        @SharedReader(.distinctFetch(FetchAllRequest(Document.list(tokens: [])))) var rows: [ArchiveSearchRow]
        let published = Mutex<[[String]]>([])
        let cancellable = $rows.publisher.sink { rows in
            published.withLock { $0.append(rows.map(\.specification)) }
        }
        defer { cancellable.cancel() }

        try await write()
        try await database.write { db in
            try Document.find(-1).update { $0.specification = "receipt" }.execute(db)
        }
        for await rows in $rows.publisher.values where rows.first?.specification == "receipt" {
            break
        }
        return published.withLock { $0 }
    }
}
