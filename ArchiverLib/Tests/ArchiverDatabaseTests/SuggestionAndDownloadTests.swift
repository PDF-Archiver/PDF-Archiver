//
//  SuggestionAndDownloadTests.swift
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
    $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
    try $0.bootstrapDatabase()
    try $0.defaultDatabase.write { db in
        try db.seed {
            Document(id: -1, rootKey: "test", url: URL(filePath: "/Archive/2024/2024-01-01--filed__bill.pdf"), date: Date(timeIntervalSince1970: 100), specification: "filed", tags: ["bill"], isTagged: true, sizeInBytes: 10, downloadStatus: 0)
            Document(id: -2, rootKey: "test", url: URL(filePath: "/Archive/untagged/scan.pdf"), date: Date(timeIntervalSince1970: 200), specification: "scan", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 0)
            Document(id: -3, rootKey: "test", url: URL(filePath: "/Archive/untagged/local.pdf"), date: Date(timeIntervalSince1970: 300), specification: "local", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
        }
    }
})
struct SuggestionAndDownloadTests {
    @Test
    func theDownloadQueueTakesTheInboxFirst() async throws {
        @Dependency(\.defaultDatabase) var database
        let documents = try await database.read { db in
            try Document.notDownloaded(limit: 10).fetchAll(db)
        }

        #expect(documents.map(\.id) == [-2, -1])
    }

    @Test
    func theDownloadQueueRespectsTheBatchSize() async throws {
        @Dependency(\.defaultDatabase) var database
        let documents = try await database.read { db in
            try Document.notDownloaded(limit: 1).fetchAll(db)
        }

        #expect(documents.map(\.id) == [-2])
    }

    /// An evicted document whose index is still fresh must not come straight back as a download
    /// candidate - otherwise eviction and prefetch churn the same document forever.
    @Test
    func theDownloadQueueSkipsAnEvictedDocumentWithAFreshIndex() async throws {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now
        try await database.write { db in
            try db.seed {
                Document(id: -4, rootKey: "test", url: URL(filePath: "/Archive/2024/evicted.pdf"), date: Date(timeIntervalSince1970: 400), specification: "evicted", tags: [], isTagged: true, sizeInBytes: 10, downloadStatus: 0)
                DocumentIndexState(documentID: -4, sourceSize: 10, sourceModificationDate: nil, indexedAt: now, outcome: .indexed, characterCount: 5, extractorVersion: DocumentIndexState.currentExtractorVersion)
            }
        }

        let documents = try await database.read { db in
            try Document.notDownloaded(limit: 10).fetchAll(db)
        }

        #expect(!documents.map(\.id).contains(-4))
    }

    /// A document whose content changed elsewhere still needs downloading, even once it carries a
    /// (now stale) index state from before.
    @Test
    func theDownloadQueueStillOffersADocumentWithAStaleIndex() async throws {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now
        try await database.write { db in
            try db.seed {
                Document(id: -4, rootKey: "test", url: URL(filePath: "/Archive/2024/stale.pdf"), date: Date(timeIntervalSince1970: 400), specification: "stale", tags: [], isTagged: true, sizeInBytes: 20, downloadStatus: 0)
                DocumentIndexState(documentID: -4, sourceSize: 10, sourceModificationDate: nil, indexedAt: now, outcome: .indexed, characterCount: 5, extractorVersion: DocumentIndexState.currentExtractorVersion)
            }
        }

        let documents = try await database.read { db in
            try Document.notDownloaded(limit: 10).fetchAll(db)
        }

        #expect(documents.map(\.id).contains(-4))
    }

    @Test
    func theTextPrefixIsCappedAtTheAnalysedLength() async throws {
        @Dependency(\.defaultDatabase) var database
        let body = String(repeating: "a", count: Document.analysedTextLength + 500)
        try await database.write { db in
            try DocumentText.insert { DocumentText(rowid: -3, body: body) }.execute(db)
        }

        let prefix = try await database.read { db in
            try DocumentText.prefix(of: -3).fetchOne(db)
        }

        #expect(prefix?.count == Document.analysedTextLength)
    }

    @Test
    func aSuggestionDisappearsWithItsDocument() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try DocumentSuggestion.insert {
                DocumentSuggestion(documentID: -3, specification: "rechnung", tags: ["bill"], createdAt: Date(timeIntervalSince1970: 0))
            }
            .execute(db)
        }

        try await database.write { db in
            try Document.find(-3).delete().execute(db)
        }

        let remaining = try await database.read { db in try DocumentSuggestion.all.fetchAll(db) }
        #expect(remaining.isEmpty)
    }
}
