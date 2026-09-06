//
//  TextIndexTests.swift
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
})
struct TextIndexTests {
    @Test
    func indexesAPdfWithATextLayer() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")

        await ArchiveIndexer().indexPendingTexts(budget: 10)

        #expect(try await Self.outcome(of: -1) == .indexed)
        #expect(try await Self.body(of: -1)?.contains("Rechnung") == true)
    }

    @Test
    func recordsAPdfWithoutATextLayerAsNoText() async throws {
        try await Self.seed(id: -1, fixture: "image-only")

        await ArchiveIndexer().indexPendingTexts(budget: 10)

        #expect(try await Self.outcome(of: -1) == .noText)
        #expect(try await Self.body(of: -1) == nil)
    }

    @Test
    func doesNotIndexMojibake() async throws {
        try await Self.seed(id: -1, fixture: "mojibake")

        await ArchiveIndexer().indexPendingTexts(budget: 10)

        #expect(try await Self.outcome(of: -1) == .unreadable)
        #expect(try await Self.body(of: -1) == nil)
    }

    @Test
    func recordsAMissingFileAsFailed() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try db.seed {
                Document(id: -1, rootKey: "test", url: URL(filePath: "/does/not/exist.pdf"), date: Date(timeIntervalSince1970: 0), specification: "gone", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
            }
        }

        await ArchiveIndexer().indexPendingTexts(budget: 10)

        #expect(try await Self.outcome(of: -1) == .failed)
    }

    @Test
    func reIndexingTheSameDocumentLeavesOneRow() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        let indexer = ArchiveIndexer()
        await indexer.indexPendingTexts(budget: 10)

        // A rewritten file: same id, new size, so the next run picks it up again.
        @Dependency(\.defaultDatabase) var database
        let mojibake = try #require(Bundle.module.url(forResource: "mojibake", withExtension: "pdf"))
        try await database.write { db in
            try Document.find(-1).update {
                $0.url = mojibake
                $0.sizeInBytes = 999
            }
            .execute(db)
        }
        await indexer.indexPendingTexts(budget: 10)

        let rows = try await database.read { db in
            try DocumentText.where { $0.rowid.eq(-1) }.fetchAll(db)
        }
        #expect(rows.isEmpty)
        #expect(try await Self.outcome(of: -1) == .unreadable)
    }

    @Test
    func skipsADocumentThatChangedDuringExtraction() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        @Dependency(\.defaultDatabase) var database
        let document = try #require(try await database.read { db in try Document.find(-1).fetchOne(db) })

        // The commit re-reads the row: a size that no longer matches means the text is stale.
        var stale = document
        stale.sizeInBytes = 12_345
        await ArchiveIndexer().commit(text: "irrelevant", for: stale)

        #expect(try await Self.body(of: -1) == nil)
        let states = try await database.read { db in try DocumentIndexState.all.fetchAll(db) }
        #expect(states.isEmpty)
    }

    @Test
    func aFailingDocumentDoesNotAbortTheRun() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try db.seed {
                Document(id: -2, rootKey: "test", url: URL(filePath: "/does/not/exist.pdf"), date: Date(timeIntervalSince1970: 500), specification: "gone", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
            }
        }

        await ArchiveIndexer().indexPendingTexts(budget: 10)

        #expect(try await Self.outcome(of: -1) == .indexed)
        #expect(try await Self.outcome(of: -2) == .failed)
    }

    @Test
    func skipsDocumentsThatAreNotDownloaded() async throws {
        try await Self.seed(id: -1, fixture: "text-layer", downloadStatus: 0)

        await ArchiveIndexer().indexPendingTexts(budget: 10)

        #expect(try await Self.outcome(of: -1) == nil)
    }

    @Test
    func indexesTheInboxFirst() async throws {
        try await Self.seed(id: -1, fixture: "text-layer", isTagged: true)
        try await Self.seed(id: -2, fixture: "text-layer", isTagged: false)

        await ArchiveIndexer().indexPendingTexts(budget: 1)

        #expect(try await Self.outcome(of: -2) == .indexed)
        #expect(try await Self.outcome(of: -1) == nil)
    }

    @Test
    func rebuildTruncatesTheReadModel() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        let indexer = ArchiveIndexer()
        await indexer.indexPendingTexts(budget: 10)

        await indexer.requestRebuild()

        @Dependency(\.defaultDatabase) var database
        let documents = try await database.read { db in try Document.all.fetchAll(db) }
        let texts = try await database.read { db in try DocumentText.all.fetchAll(db) }
        let states = try await database.read { db in try DocumentIndexState.all.fetchAll(db) }
        let rebuildRequested = try await database.read { db in
            try IndexerState.find(IndexerState.singletonID).select(\.rebuildRequested).fetchOne(db)
        }

        #expect(documents.isEmpty)
        #expect(texts.isEmpty)
        #expect(states.isEmpty)
        #expect(rebuildRequested == true)
    }

    @Test
    func deletingADocumentRemovesItsText() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        let indexer = ArchiveIndexer()
        await indexer.indexPendingTexts(budget: 10)
        #expect(try await Self.body(of: -1) != nil)

        let generation = await indexer.setObservedRoots(["test"])
        await indexer.reconcile([], root: "test", generation: generation)

        #expect(try await Self.body(of: -1) == nil)
    }

    @Test
    func theStatusCountsIndexedPendingAndUndownloadedDocuments() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        try await Self.seed(id: -2, fixture: "text-layer")
        try await Self.seed(id: -3, fixture: "text-layer", downloadStatus: 0)
        await ArchiveIndexer().indexPendingTexts(budget: 1)

        @Dependency(\.defaultDatabase) var database
        let status = try await database.read { db in
            try DocumentIndexState.StatusRequest().fetch(db)
        }

        #expect(status.indexed == 1)
        #expect(status.pending == 1)
        #expect(status.notDownloaded == 1)
        #expect(status.lastRun != nil)
    }

    // MARK: - Helpers

    private static func seed(id: Document.ID,
                             fixture: String,
                             isTagged: Bool = false,
                             downloadStatus: Double = 1) async throws {
        @Dependency(\.defaultDatabase) var database
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "pdf"))
        let size = Double(try #require(try FileManager.default.attributesOfItem(atPath: url.path())[.size] as? Int))
        try await database.write { db in
            try Document.insert {
                Document(id: id, rootKey: "test", url: url, date: Date(timeIntervalSince1970: 0), specification: fixture, tags: [], isTagged: isTagged, sizeInBytes: size, downloadStatus: downloadStatus)
            }
            .execute(db)
        }
    }

    private static func outcome(of id: Document.ID) async throws -> DocumentIndexState.Outcome? {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try DocumentIndexState.find(id).select(\.outcome).fetchOne(db).flatMap(\.self)
        }
    }

    private static func body(of id: Document.ID) async throws -> String? {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try DocumentText.where { $0.rowid.eq(id) }.select(\.body).fetchOne(db)
        }
    }
}
