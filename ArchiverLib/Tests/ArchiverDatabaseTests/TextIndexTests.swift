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
    func doesNotIndexWhileAReconcileIsRunning() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try IndexerState.find(IndexerState.singletonID).update { $0.isReconciling = true }.execute(db)
        }

        await ArchiveIndexer().indexPendingTexts(budget: 10)

        #expect(try await Self.outcome(of: -1) == nil)
        #expect(try await Self.body(of: -1) == nil)
        // No bookkeeping either, so the next scheduled run repeats the attempt.
        #expect(try await Self.lastRun() == nil)
    }

    /// The cold-start sequence a background run follows: wait out the reconcile, then index. It
    /// used to give up after 30 seconds and index nothing at all.
    @Test
    func theTextPassStartsOnceTheReconcileFinishes() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try IndexerState.find(IndexerState.singletonID).update { $0.isReconciling = true }.execute(db)
        }
        let indexer = ArchiveIndexer()

        let run = Task {
            let reconciled = await indexer.waitWhileReconciling(timeout: .seconds(30))
            await indexer.indexPendingTexts(budget: 10)
            return reconciled
        }
        // Long enough for the observation to be live; the flag is what holds the run, not the sleep.
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await Self.outcome(of: -1) == nil)

        try await database.write { db in
            try IndexerState.find(IndexerState.singletonID).update { $0.isReconciling = false }.execute(db)
        }

        let reconciled = await run.value
        #expect(reconciled)
        #expect(try await Self.outcome(of: -1) == .indexed)
    }

    /// The provider of an observed root never yields, so nothing ever lowers the flag.
    @Test
    func aReconcileFlagThatNeverClearsStopsBlockingTheTextPass() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try IndexerState.find(IndexerState.singletonID).update { $0.isReconciling = true }.execute(db)
        }
        let indexer = ArchiveIndexer()

        await indexer.indexPendingTexts(budget: 10)
        #expect(try await Self.outcome(of: -1) == nil)

        @Dependency(\.date.now) var now
        await withDependencies {
            $0.date = .constant(now.addingTimeInterval(ArchiveIndexer.reconcileDeadline))
        } operation: {
            await indexer.indexPendingTexts(budget: 10)
        }

        #expect(try await Self.outcome(of: -1) == .indexed)
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

    /// A cancelled run must leave the document pending, not record a permanent failure for the
    /// size and date it never finished reading.
    @Test
    func aCancelledRunLeavesTheDocumentPending() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        let indexer = ArchiveIndexer()

        let run = Task { await indexer.indexPendingTexts(budget: 10) }
        run.cancel()
        await run.value

        #expect(try await Self.outcome(of: -1) == nil)
        #expect(try await Self.body(of: -1) == nil)
        #expect(try await Self.pendingCount() == 1)

        // The next run still picks it up.
        await indexer.indexPendingTexts(budget: 10)
        #expect(try await Self.outcome(of: -1) == .indexed)
    }

    @Test
    func aFullOptimizeOnlyFollowsACompletedRebuild() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        let indexer = ArchiveIndexer()
        await indexer.indexPendingTexts(budget: 10)
        #expect(try await Self.rebuildRequested() == false)

        try await Self.seed(id: -2, fixture: "text-layer")
        try await Self.seed(id: -3, fixture: "text-layer")
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try IndexerState.find(IndexerState.singletonID).update { $0.rebuildRequested = true }.execute(db)
        }

        // Budget too small to catch up: the flag stays, so no optimize yet.
        await indexer.indexPendingTexts(budget: 1)
        #expect(try await Self.rebuildRequested() == true)

        await indexer.indexPendingTexts(budget: 10)
        #expect(try await Self.rebuildRequested() == false)
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

        #expect(status.total == 3)
        #expect(status.indexed == 1)
        #expect(status.pending == 1)
        #expect(status.notDownloaded == 1)
        #expect(status.lastRun != nil)
    }

    @Test
    func theStatusSeparatesDocumentsWithoutTextFromFailures() async throws {
        try await Self.seed(id: -1, fixture: "text-layer")
        try await Self.seed(id: -2, fixture: "image-only")
        try await Self.seed(id: -3, fixture: "mojibake")
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try db.seed {
                Document(id: -4, rootKey: "test", url: URL(filePath: "/does/not/exist.pdf"), date: Date(timeIntervalSince1970: 0), specification: "gone", tags: [], isTagged: false, sizeInBytes: 10, downloadStatus: 1)
            }
        }
        await ArchiveIndexer().indexPendingTexts(budget: 10)

        let status = try await database.read { db in
            try DocumentIndexState.StatusRequest().fetch(db)
        }

        #expect(status.total == 4)
        #expect(status.indexed == 1)
        // A PDF without a text layer and an unreadable one are both "without text", not failures.
        #expect(status.withoutText == 2)
        #expect(status.failed == 1)
        #expect(status.pending == 0)
    }

    @Test
    func aDocumentWithoutATextLayerIsNotOfferedAgain() async throws {
        try await Self.seed(id: -1, fixture: "image-only")
        let indexer = ArchiveIndexer()
        await indexer.indexPendingTexts(budget: 10)
        #expect(try await Self.pendingCount() == 0)

        await indexer.indexPendingTexts(budget: 10)

        #expect(try await Self.outcome(of: -1) == .noText)
        #expect(try await Self.pendingCount() == 0)
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

    private static func pendingCount() async throws -> Int {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try ArchiveIndexer.pendingCount().fetchOne(db) ?? 0
        }
    }

    private static func lastRun() async throws -> Date? {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try IndexerState.find(IndexerState.singletonID).select(\.lastTextRunFinishedAt).fetchOne(db).flatMap(\.self)
        }
    }

    private static func rebuildRequested() async throws -> Bool {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try IndexerState.find(IndexerState.singletonID).select(\.rebuildRequested).fetchOne(db) ?? false
        }
    }

    private static func body(of id: Document.ID) async throws -> String? {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try DocumentText.where { $0.rowid.eq(id) }.select(\.body).fetchOne(db)
        }
    }
}
