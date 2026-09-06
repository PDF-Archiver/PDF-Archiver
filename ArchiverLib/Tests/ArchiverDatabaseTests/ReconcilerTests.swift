//
//  ReconcilerTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Dependencies
import DependenciesTestSupport
import Foundation
import GRDB
import SQLiteData
import Synchronization
import Testing

@testable import ArchiverDatabase

@Suite(.dependencies {
    $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
    try $0.bootstrapDatabase()
})
struct ReconcilerTests {
    private let archiveRoot = "icloud"

    @Test
    func insertsANewSnapshot() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill_energy.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)

        let document = try #require(try await Self.document(1))
        #expect(document.rootKey == archiveRoot)
        #expect(document.filename == "2024-01-02--rechnung__bill_energy.pdf")
        #expect(document.specification == "rechnung")
        #expect(document.tags == ["bill", "energy"])
        #expect(document.year == 2024)
        #expect(document.isTagged)
        #expect(try await Self.tags(of: 1) == ["bill", "energy"])
    }

    @Test
    func separatesArchiveAndInboxInsideOneRoot() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(
            [
                Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill.pdf", isTagged: true),
                Self.item(id: 2, path: "/Archive/untagged/scan.pdf", isTagged: false),
                // A placeholder name inside a year folder is not tagged either - `ArchiveStore` decides.
                Self.item(id: 3, path: "/Archive/2024/2024-01-02--pdf-archiver-temp-description-__bill.pdf", isTagged: false)
            ],
            root: archiveRoot,
            generation: generation
        )

        #expect(try await Self.count(tagged: true) == 1)
        #expect(try await Self.count(tagged: false) == 2)
    }

    @Test
    func renameFromInboxIntoTheArchiveKeepsTheID() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/untagged/scan.pdf", isTagged: false)],
                                root: archiveRoot,
                                generation: generation)
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-03-04--strom__energy.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)

        let document = try #require(try await Self.document(1))
        #expect(document.isTagged)
        #expect(document.specification == "strom")
        #expect(document.year == 2024)
        #expect(try await Self.tags(of: 1) == ["energy"])
        #expect(try await Self.allDocuments().count == 1)
    }

    @Test
    func replacingAFileAtTheSamePathSwapsTheRow() async throws {
        let path = "/Archive/2024/2024-01-02--rechnung__bill.pdf"
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: path, isTagged: true)], root: archiveRoot, generation: generation)
        await indexer.reconcile([Self.item(id: 2, path: path, isTagged: true)], root: archiveRoot, generation: generation)

        #expect(try await Self.document(1) == nil)
        #expect(try await Self.document(2) != nil)
        #expect(try await Self.allDocuments().count == 1)
    }

    @Test
    func appliesARenameChainInOneSnapshot() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(
            [
                Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true),
                Self.item(id: 2, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true)
            ],
            root: archiveRoot,
            generation: generation
        )

        // 1 takes 2's name, 2 moves on - the intermediate state has two rows on one URL.
        await indexer.reconcile(
            [
                Self.item(id: 1, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true),
                Self.item(id: 2, path: "/Archive/2024/2024-01-03--c__x.pdf", isTagged: true)
            ],
            root: archiveRoot,
            generation: generation
        )

        #expect(try await Self.document(1)?.filename == "2024-01-02--b__x.pdf")
        #expect(try await Self.document(2)?.filename == "2024-01-03--c__x.pdf")
    }

    @Test
    func appliesASwapInOneSnapshot() async throws {
        let pathA = "/Archive/2024/2024-01-01--a__x.pdf"
        let pathB = "/Archive/2024/2024-01-02--b__x.pdf"
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(
            [
                Self.item(id: 1, path: pathA, isTagged: true),
                Self.item(id: 2, path: pathB, isTagged: true)
            ],
            root: archiveRoot,
            generation: generation
        )

        await indexer.reconcile(
            [
                Self.item(id: 1, path: pathB, isTagged: true),
                Self.item(id: 2, path: pathA, isTagged: true)
            ],
            root: archiveRoot,
            generation: generation
        )

        #expect(try await Self.document(1)?.filename == "2024-01-02--b__x.pdf")
        #expect(try await Self.document(2)?.filename == "2024-01-01--a__x.pdf")
    }

    @Test
    func deleteCascadesToTags() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)
        await indexer.reconcile([], root: archiveRoot, generation: generation)

        #expect(try await Self.allDocuments().isEmpty)
        #expect(try await Self.tags(of: 1).isEmpty)
    }

    @Test
    func dropsASnapshotOfAnUnobservedRoot() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Other/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: "someOtherRoot",
                                generation: generation)

        #expect(try await Self.allDocuments().isEmpty)
    }

    @Test
    func dropsASnapshotOfAStaleGeneration() async throws {
        let indexer = ArchiveIndexer()
        let stale = await indexer.setObservedRoots([archiveRoot])
        _ = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: stale)

        #expect(try await Self.allDocuments().isEmpty)
    }

    @Test
    func removesRowsOfARootThatIsNoLongerObservedOnceALiveRootReports() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot, "local"])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)
        await indexer.reconcile([Self.item(id: 2, path: "/Local/2024/2024-01-03--z__y.pdf", isTagged: true)],
                                root: "local",
                                generation: generation)
        try await Self.indexText("gone soon", for: 2)

        let next = await indexer.setObservedRoots([archiveRoot])
        #expect(try await Self.allDocuments().count == 2)

        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: next)

        #expect(try await Self.allDocuments().map(\.id) == [1])
        #expect(try await Self.hasText(2) == false)
    }

    @Test
    func keepsEveryDocumentWhenNoRootIsObserved() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)

        _ = await indexer.setObservedRoots([])

        #expect(try await Self.allDocuments().count == 1)
    }

    @Test
    func keepsEveryDocumentWhileANewGenerationHasNotReported() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)

        _ = await indexer.setObservedRoots(["anotherRoot"])

        #expect(try await Self.allDocuments().count == 1)
    }

    @Test
    func aDuplicatedIdentifierDoesNotWedgeTheRoot() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await withKnownIssue("the collision is reported, not swallowed") {
            await indexer.reconcile(
                [
                    Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true),
                    Self.item(id: 1, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true)
                ],
                root: archiveRoot,
                generation: generation
            )
        }

        #expect(try await Self.allDocuments().count == 1)
    }

    @Test
    func aDownloadProgressUpdateKeepsTheParsedFields() async throws {
        let path = "/Archive/2024/2024-01-02--rechnung__bill.pdf"
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: path, isTagged: true, downloadStatus: 0)],
                                root: archiveRoot,
                                generation: generation)
        await indexer.reconcile([Self.item(id: 1, path: path, isTagged: true, downloadStatus: 1)],
                                root: archiveRoot,
                                generation: generation)

        let document = try #require(try await Self.document(1))
        #expect(document.downloadStatus == 1)
        #expect(document.tags == ["bill"])
    }

    @Test
    func aFailedWriteFallsBackToReplacingTheRoot() async throws {
        @Dependency(\.defaultDatabase) var database
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)

        // The diff wants to UPDATE row 1 and INSERT row 2; this makes only the update fail, so the
        // first write throws and the "replace root" retry has to put both rows back.
        try await database.write { db in
            try #sql("""
                CREATE TRIGGER "reject_updates" BEFORE UPDATE ON "documents"
                BEGIN SELECT RAISE(ABORT, 'no updates'); END
                """)
                .execute(db)
        }
        defer {
            try? database.write { db in
                try #sql(#"DROP TRIGGER "reject_updates""#).execute(db)
            }
        }

        await withKnownIssue("the failing write is reported before the retry") {
            await indexer.reconcile(
                [
                    Self.item(id: 1, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true),
                    Self.item(id: 2, path: "/Archive/2024/2024-01-03--c__y.pdf", isTagged: true)
                ],
                root: archiveRoot,
                generation: generation
            )
        }

        #expect(try await Self.document(1)?.filename == "2024-01-02--b__x.pdf")
        #expect(try await Self.document(2)?.filename == "2024-01-03--c__y.pdf")
        #expect(try await Self.tags(of: 2) == ["y"])
    }

    /// The guard is re-checked before the write, because the actor is reentrant and every rescan
    /// bumps the generation.
    @Test
    func aSnapshotWhoseGenerationExpiresWhileItIsDiffedIsDropped() async throws {
        let indexer = ArchiveIndexer()
        let stale = await indexer.setObservedRoots([archiveRoot])

        async let reconcile: Void = indexer.reconcile(
            [Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true)],
            root: archiveRoot,
            generation: stale
        )
        _ = await indexer.setObservedRoots(["anotherRoot"])
        await reconcile

        #expect(try await Self.allDocuments().isEmpty)
    }

    @Test
    func derivesTheYearFromTheCreationDateOfAnUntaggedScan() async throws {
        let creationDate = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2019, month: 6, day: 1)))
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/untagged/scan.pdf", isTagged: false, creationDate: creationDate)],
                                root: archiveRoot,
                                generation: generation)

        #expect(try await Self.document(1)?.year == 2019)
    }

    @Test
    func clearsTheReconcilingFlagOnceEveryRootDelivered() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot, "local"])
        await indexer.reconcile([], root: archiveRoot, generation: generation)
        #expect(try await Self.isReconciling())

        await indexer.reconcile([], root: "local", generation: generation)
        #expect(try await Self.isReconciling() == false)
    }

    @Test
    func tagCountObservationRefreshesAfterAReconcile() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)

        @FetchAll(DocumentTag.counts(limit: 10)) var usage: [TagUsage]
        try await $usage.load()
        #expect(usage.map(\.tag) == ["bill"])

        // Only the tags change, so a broken observation on `documentTags` would go unnoticed here.
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill_energy.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)
        try await Task.sleep(for: .milliseconds(500))

        #expect(usage.map(\.tag) == ["bill", "energy"])
    }

    // MARK: - Chunking

    @Test
    func aLargeSnapshotIsWrittenInChunks() async throws {
        @Dependency(\.defaultDatabase) var database
        let items = (1...600).map {
            Self.item(id: $0, path: "/Archive/2024/2024-01-02--doc-\($0)__x.pdf", isTagged: true)
        }
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        let counter = DocumentWriteCounter()
        database.add(transactionObserver: counter, extent: .observerLifetime)

        await indexer.reconcile(items, root: archiveRoot, generation: generation)

        #expect(counter.transactions == 3)
        #expect(try await Self.allDocuments().count == 600)
    }

    @Test
    func aStaleGenerationStopsTheChunkLoopAndKeepsWhatLanded() async throws {
        let items = (1...2000).map {
            Self.item(id: $0, path: "/Archive/2024/2024-01-02--doc-\($0)__x.pdf", isTagged: true)
        }
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])

        // The loop yields between chunks, so the bump below is picked up at the next boundary.
        async let reconcile: Void = indexer.reconcile(items, root: archiveRoot, generation: generation)
        while try await Self.allDocuments().count < ArchiveIndexer.chunkSize {
            await Task.yield()
        }
        _ = await indexer.setObservedRoots([archiveRoot])
        await reconcile

        let stored = try await Self.allDocuments()
        #expect(stored.count >= ArchiveIndexer.chunkSize)
        #expect(stored.count < items.count)
    }

    @Test
    func aWarmStartShowsTheStoredRowsWithoutTheSpinner() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        #expect(try await Self.isReconciling())
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)

        _ = await indexer.setObservedRoots([archiveRoot])

        #expect(try await Self.isReconciling() == false)
        #expect(try await Self.allDocuments().count == 1)
    }

    // MARK: - Planning

    @Test
    func planLeavesAnUnchangedSnapshotAlone() async throws {
        let items = [Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill.pdf", isTagged: true)]
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(items, root: archiveRoot, generation: generation)

        var existing: [Document.ID: Document] = [:]
        for row in try await Self.allDocuments() {
            existing[row.id] = row
        }
        var documents: [Document.ID: Document] = [:]
        for item in items {
            documents[item.id] = await Document.make(from: item, rootKey: archiveRoot)
        }

        let plan = ArchiveIndexer.plan(items: items, existing: existing, root: archiveRoot, documents: documents)

        #expect(plan == ArchiveIndexer.ReconcilePlan())
    }

    @Test
    func reconcilingTheIdenticalSnapshotTwiceWritesNothing() async throws {
        @Dependency(\.defaultDatabase) var database
        let items = [
            Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill.pdf", isTagged: true),
            Self.item(id: 2, path: "/Archive/untagged/scan.pdf", isTagged: false, creationDate: Self.fileSystemDate)
        ]
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(items, root: archiveRoot, generation: generation)
        let before = try await Self.allDocuments()

        // Any row the second snapshot rewrites aborts its transaction, and the reported error
        // fails this test - a silent full rewrite cannot pass.
        try await database.write { db in
            try #sql("""
                CREATE TRIGGER "reject_updates" BEFORE UPDATE ON "documents"
                BEGIN SELECT RAISE(ABORT, 'no updates'); END
                """)
                .execute(db)
        }
        defer {
            try? database.write { db in
                try #sql(#"DROP TRIGGER "reject_updates""#).execute(db)
            }
        }

        await indexer.reconcile(items, root: archiveRoot, generation: generation)

        #expect(try await Self.allDocuments() == before)
    }

    @Test
    func planOrdersTheChangedRowsNewestFirst() async throws {
        let items = [
            Self.item(id: 1, path: "/Archive/2024/2024-01-02--a__x.pdf", isTagged: true),
            Self.item(id: 2, path: "/Archive/2024/2024-03-04--b__x.pdf", isTagged: true),
            Self.item(id: 3, path: "/Archive/2024/2024-02-03--c__x.pdf", isTagged: true)
        ]
        var documents: [Document.ID: Document] = [:]
        for item in items {
            documents[item.id] = await Document.make(from: item, rootKey: archiveRoot)
        }

        let plan = ArchiveIndexer.plan(items: items, existing: [:], root: archiveRoot, documents: documents)

        #expect(plan.changed.map(\.id) == [2, 3, 1])
    }

    // MARK: - Helpers

    /// Sub-millisecond, like the dates the file system reports.
    private static let fileSystemDate = Date(timeIntervalSince1970: 1_759_576_537.427_740_3)

    private static func item(id: Document.ID,
                             path: String,
                             isTagged: Bool,
                             size: Double = 100,
                             downloadStatus: Double = 1,
                             creationDate: Date? = nil,
                             contentModificationDate: Date? = fileSystemDate) -> DocumentSnapshotItem {
        DocumentSnapshotItem(id: id,
                             url: URL(filePath: path),
                             isTagged: isTagged,
                             sizeInBytes: size,
                             downloadStatus: downloadStatus,
                             creationDate: creationDate,
                             contentModificationDate: contentModificationDate)
    }

    private static func document(_ id: Document.ID) async throws -> Document? {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try Document.find(id).fetchOne(db)
        }
    }

    private static func allDocuments() async throws -> [Document] {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try Document.all.fetchAll(db)
        }
    }

    private static func count(tagged: Bool) async throws -> Int {
        try await allDocuments().count { $0.isTagged == tagged }
    }

    private static func tags(of id: Document.ID) async throws -> [String] {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try DocumentTag.where { $0.documentID.eq(id) }.order(by: \.tag).select(\.tag).fetchAll(db)
        }
    }

    private static func indexText(_ body: String, for id: Document.ID) async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try DocumentText.insert { DocumentText(rowid: id, body: body) }.execute(db)
        }
    }

    private static func hasText(_ id: Document.ID) async throws -> Bool {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try DocumentText.where { $0.rowid.eq(id) }.fetchCount(db) > 0
        }
    }

    private static func isReconciling() async throws -> Bool {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try IndexerState.find(IndexerState.singletonID).select(\.isReconciling).fetchOne(db) ?? false
        }
    }
}

/// Counts the transactions that changed `documents`, so "the snapshot lands in chunks" is a plain
/// number instead of a race with the observation.
private final class DocumentWriteCounter: TransactionObserver, Sendable {
    private struct Counts {
        var transactions = 0
        var touchedDocuments = false
    }

    private let counts = Mutex(Counts())

    var transactions: Int {
        counts.withLock { $0.transactions }
    }

    func observes(eventsOfKind kind: DatabaseEventKind) -> Bool {
        kind.tableName == Document.tableName
    }

    func databaseDidChange(with event: DatabaseEvent) {
        counts.withLock { $0.touchedDocuments = true }
    }

    func databaseDidCommit(_ db: Database) {
        counts.withLock {
            guard $0.touchedDocuments else { return }
            $0.transactions += 1
            $0.touchedDocuments = false
        }
    }

    func databaseDidRollback(_ db: Database) {
        counts.withLock { $0.touchedDocuments = false }
    }
}
