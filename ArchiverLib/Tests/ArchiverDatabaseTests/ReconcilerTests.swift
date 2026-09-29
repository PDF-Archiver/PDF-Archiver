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
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill_energy.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
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
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(
            [
                Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill.pdf", isTagged: true),
                Self.item(id: 2, path: "/Archive/untagged/scan.pdf", isTagged: false),
                // A placeholder name inside a year folder is not tagged either - `ArchiveStore` decides.
                Self.item(id: 3, path: "/Archive/2024/2024-01-02--pdf-archiver-temp-description-__bill.pdf", isTagged: false)
            ],
            root: archiveRoot,
            rootURL: Self.archiveURL,
            generation: generation
        )

        #expect(try await Self.count(tagged: true) == 1)
        #expect(try await Self.count(tagged: false) == 2)
    }

    @Test
    func renameFromInboxIntoTheArchiveKeepsTheID() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/untagged/scan.pdf", isTagged: false)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-03-04--strom__energy.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
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
        // The path exists - it holds the new file - so only the snapshot claiming it removes row 1.
        let indexer = Self.makeIndexer(existingPaths: [path])
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: path, isTagged: true)], root: archiveRoot, rootURL: Self.archiveURL, generation: generation)
        await indexer.reconcile([Self.item(id: 2, path: path, isTagged: true)], root: archiveRoot, rootURL: Self.archiveURL, generation: generation)

        #expect(try await Self.document(1) == nil)
        #expect(try await Self.document(2) != nil)
        #expect(try await Self.allDocuments().count == 1)
    }

    @Test
    func appliesARenameChainInOneSnapshot() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(
            [
                Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true),
                Self.item(id: 2, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true)
            ],
            root: archiveRoot,
            rootURL: Self.archiveURL,
            generation: generation
        )

        // 1 takes 2's name, 2 moves on - the intermediate state has two rows on one URL.
        await indexer.reconcile(
            [
                Self.item(id: 1, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true),
                Self.item(id: 2, path: "/Archive/2024/2024-01-03--c__x.pdf", isTagged: true)
            ],
            root: archiveRoot,
            rootURL: Self.archiveURL,
            generation: generation
        )

        #expect(try await Self.document(1)?.filename == "2024-01-02--b__x.pdf")
        #expect(try await Self.document(2)?.filename == "2024-01-03--c__x.pdf")
    }

    @Test
    func appliesASwapInOneSnapshot() async throws {
        let pathA = "/Archive/2024/2024-01-01--a__x.pdf"
        let pathB = "/Archive/2024/2024-01-02--b__x.pdf"
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(
            [
                Self.item(id: 1, path: pathA, isTagged: true),
                Self.item(id: 2, path: pathB, isTagged: true)
            ],
            root: archiveRoot,
            rootURL: Self.archiveURL,
            generation: generation
        )

        await indexer.reconcile(
            [
                Self.item(id: 1, path: pathB, isTagged: true),
                Self.item(id: 2, path: pathA, isTagged: true)
            ],
            root: archiveRoot,
            rootURL: Self.archiveURL,
            generation: generation
        )

        #expect(try await Self.document(1)?.filename == "2024-01-02--b__x.pdf")
        #expect(try await Self.document(2)?.filename == "2024-01-01--a__x.pdf")
    }

    @Test
    func deleteCascadesToTags() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)
        await indexer.reconcile([], root: archiveRoot, rootURL: Self.archiveURL, generation: generation)

        #expect(try await Self.allDocuments().isEmpty)
        #expect(try await Self.tags(of: 1).isEmpty)
    }

    @Test
    func dropsASnapshotOfAnUnobservedRoot() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Other/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: "someOtherRoot",
                                rootURL: URL(filePath: "/Other"),
                                generation: generation)

        #expect(try await Self.allDocuments().isEmpty)
    }

    @Test
    func dropsASnapshotOfAStaleGeneration() async throws {
        let indexer = Self.makeIndexer()
        let stale = await indexer.setObservedRoots([archiveRoot])
        _ = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: stale)

        #expect(try await Self.allDocuments().isEmpty)
    }

    @Test
    func removesRowsOfARootThatIsNoLongerObservedOnceALiveRootReports() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot, "local"])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)
        await indexer.reconcile([Self.item(id: 2, path: "/Local/2024/2024-01-03--z__y.pdf", isTagged: true)],
                                root: "local",
                                rootURL: Self.localURL,
                                generation: generation)
        try await Self.indexText("gone soon", for: 2)

        let next = await indexer.setObservedRoots([archiveRoot])
        #expect(try await Self.allDocuments().count == 2)

        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: next)

        #expect(try await Self.allDocuments().map(\.id) == [1])
        #expect(try await Self.hasText(2) == false)
    }

    @Test
    func keepsEveryDocumentWhenNoRootIsObserved() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)

        _ = await indexer.setObservedRoots([])

        #expect(try await Self.allDocuments().count == 1)
    }

    @Test
    func keepsEveryDocumentWhileANewGenerationHasNotReported() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)

        _ = await indexer.setObservedRoots(["anotherRoot"])

        #expect(try await Self.allDocuments().count == 1)
    }

    @Test
    func aDuplicatedIdentifierDoesNotWedgeTheRoot() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await withKnownIssue("the collision is reported, not swallowed") {
            await indexer.reconcile(
                [
                    Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true),
                    Self.item(id: 1, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true)
                ],
                root: archiveRoot,
                rootURL: Self.archiveURL,
                generation: generation
            )
        }

        #expect(try await Self.allDocuments().count == 1)
    }

    @Test
    func aDownloadProgressUpdateKeepsTheParsedFields() async throws {
        let path = "/Archive/2024/2024-01-02--rechnung__bill.pdf"
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: path, isTagged: true, downloadStatus: 0)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)
        await indexer.reconcile([Self.item(id: 1, path: path, isTagged: true, downloadStatus: 1)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)

        let document = try #require(try await Self.document(1))
        #expect(document.downloadStatus == 1)
        #expect(document.tags == ["bill"])
    }

    @Test
    func aFailedWriteFallsBackToReplacingTheRoot() async throws {
        @Dependency(\.defaultDatabase) var database
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
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
                rootURL: Self.archiveURL,
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
        let indexer = Self.makeIndexer()
        let stale = await indexer.setObservedRoots([archiveRoot])

        async let reconcile: Void = indexer.reconcile(
            [Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true)],
            root: archiveRoot,
            rootURL: Self.archiveURL,
            generation: stale
        )
        _ = await indexer.setObservedRoots(["anotherRoot"])
        await reconcile

        #expect(try await Self.allDocuments().isEmpty)
    }

    @Test
    func derivesTheYearFromTheCreationDateOfAnUntaggedScan() async throws {
        let creationDate = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2019, month: 6, day: 1)))
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/untagged/scan.pdf", isTagged: false, creationDate: creationDate)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)

        #expect(try await Self.document(1)?.year == 2019)
    }

    /// One root is enough: waiting for every root leaves the indicator spinning for the rest of the
    /// process as soon as one provider never delivers a snapshot.
    @Test
    func clearsTheReconcilingFlagAsSoonAsOneRootDelivers() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot, "local"])
        #expect(try await Self.isReconciling())

        await indexer.reconcile([], root: archiveRoot, rootURL: Self.archiveURL, generation: generation)

        #expect(try await Self.isReconciling() == false)
    }

    /// A reconcile that cannot even read the stored rows still has to lower the flag: it gates the
    /// progress indicator and the text pass.
    @Test
    func aFailedReadClearsTheReconcilingFlag() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        #expect(try await Self.isReconciling())

        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try #sql(#"DROP TABLE "documents""#).execute(db)
        }

        await withKnownIssue("the failed read is reported") {
            await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--a__x.pdf", isTagged: true)],
                                    root: archiveRoot,
                                    rootURL: Self.archiveURL,
                                    generation: generation)
        }

        #expect(try await Self.isReconciling() == false)
    }

    @Test
    func tagCountObservationRefreshesAfterAReconcile() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)

        @FetchAll(DocumentTag.counts(limit: 10)) var usage: [TagUsage]
        try await $usage.load()
        #expect(usage.map(\.tag) == ["bill"])

        // Only the tags change, so a broken observation on `documentTags` would go unnoticed here.
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--rechnung__bill_energy.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)
        try await Task.sleep(for: .milliseconds(500))

        #expect(usage.map(\.tag) == ["bill", "energy"])
    }

    // MARK: - Deletion needs evidence

    @Test
    func aPartialSnapshotKeepsDocumentsWhoseFilesExist() async throws {
        let missedPath = "/Archive/2024/2024-01-03--b__x.pdf"
        let indexer = Self.makeIndexer(existingPaths: [missedPath])
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(
            [
                Self.item(id: 1, path: "/Archive/2024/2024-01-02--a__x.pdf", isTagged: true),
                Self.item(id: 2, path: missedPath, isTagged: true)
            ],
            root: archiveRoot,
            rootURL: Self.archiveURL,
            generation: generation
        )
        try await Self.addDerivedData(for: 2)

        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--a__x.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)

        #expect(try await Self.document(2) != nil)
        #expect(try await Self.hasText(2))
        #expect(try await Self.hasIndexState(2))
        #expect(try await Self.hasSuggestion(2))
    }

    @Test
    func aDocumentWhoseFileIsGoneIsRemovedWithItsDerivedData() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--a__x.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)
        try await Self.addDerivedData(for: 1)

        await indexer.reconcile([], root: archiveRoot, rootURL: Self.archiveURL, generation: generation)

        #expect(try await Self.document(1) == nil)
        #expect(try await Self.hasText(1) == false)
        #expect(try await Self.hasIndexState(1) == false)
        #expect(try await Self.hasSuggestion(1) == false)
    }

    @Test
    func anICloudPlaceholderCountsAsAnExistingFile() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let downloaded = folder.appending(path: "2024-01-02--a__x.pdf")
        let evicted = folder.appending(path: "2024-01-03--b__x.pdf")
        let deleted = folder.appending(path: "2024-01-04--c__x.pdf")
        try Data().write(to: downloaded)
        try Data().write(to: folder.appending(path: ".2024-01-03--b__x.pdf.icloud"))

        #expect(ArchiveIndexer.fileOrPlaceholderExists(downloaded))
        #expect(ArchiveIndexer.fileOrPlaceholderExists(evicted))
        #expect(ArchiveIndexer.fileOrPlaceholderExists(deleted) == false)
    }

    @Test
    func anUnreachableRootRemovesNothing() async throws {
        let indexer = ArchiveIndexer { _ in false }
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--a__x.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)

        await indexer.reconcile([], root: archiveRoot, rootURL: Self.archiveURL, generation: generation)

        #expect(try await Self.document(1) != nil)
    }

    @Test
    func aRenameKeepsTheIndexState() async throws {
        let indexer = Self.makeIndexer(existingPaths: ["/Archive/2024/2024-01-02--a__x.pdf"])
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--a__x.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)
        try await Self.addDerivedData(for: 1)

        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)

        #expect(try await Self.document(1)?.filename == "2024-01-02--b__x.pdf")
        #expect(try await Self.hasIndexState(1))
    }

    @Test
    func aFailedWriteKeepsTheRowsWhoseFilesExist() async throws {
        @Dependency(\.defaultDatabase) var database
        let missedPath = "/Archive/2024/2024-01-05--missed__x.pdf"
        let indexer = Self.makeIndexer(existingPaths: [missedPath])
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(
            [
                Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true),
                Self.item(id: 3, path: missedPath, isTagged: true)
            ],
            root: archiveRoot,
            rootURL: Self.archiveURL,
            generation: generation
        )
        try await Self.addDerivedData(for: 3)

        // Only the update of row 1 fails, so the write throws and `replaceRoot` takes over.
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
            await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true)],
                                    root: archiveRoot,
                                    rootURL: Self.archiveURL,
                                    generation: generation)
        }

        #expect(try await Self.document(1)?.filename == "2024-01-02--b__x.pdf")
        #expect(try await Self.document(3) != nil)
        #expect(try await Self.hasText(3))
        #expect(try await Self.hasIndexState(3))
    }

    // MARK: - Chunking

    @Test
    func aLargeSnapshotIsWrittenInChunks() async throws {
        @Dependency(\.defaultDatabase) var database
        let items = (1...600).map {
            Self.item(id: $0, path: "/Archive/2024/2024-01-02--doc-\($0)__x.pdf", isTagged: true)
        }
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        let counter = DocumentWriteCounter()
        database.add(transactionObserver: counter, extent: .observerLifetime)

        await indexer.reconcile(items, root: archiveRoot, rootURL: Self.archiveURL, generation: generation)

        #expect(counter.transactions == 3)
        #expect(try await Self.allDocuments().count == 600)
    }

    @Test
    func aStaleGenerationStopsTheChunkLoopAndKeepsWhatLanded() async throws {
        let items = (1...2000).map {
            Self.item(id: $0, path: "/Archive/2024/2024-01-02--doc-\($0)__x.pdf", isTagged: true)
        }
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])

        // The loop yields between chunks, so the bump below is picked up at the next boundary.
        async let reconcile: Void = indexer.reconcile(items, root: archiveRoot, rootURL: Self.archiveURL, generation: generation)
        while try await Self.allDocuments().count < ArchiveIndexer.chunkSize {
            await Task.yield()
        }
        _ = await indexer.setObservedRoots([archiveRoot])
        await reconcile

        let stored = try await Self.allDocuments()
        #expect(stored.count >= ArchiveIndexer.chunkSize)
        #expect(stored.count < items.count)
    }

    /// The indicator means "nothing to show yet". `reloadDocuments()` runs after every OCR pass and
    /// tears the providers down, so a per-rescan indicator strands on the next teardown.
    @Test
    func aWarmStartShowsTheStoredRowsWithoutTheSpinner() async throws {
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        #expect(try await Self.isReconciling())
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                rootURL: Self.archiveURL,
                                generation: generation)

        _ = await indexer.setObservedRoots([archiveRoot])

        #expect(try await Self.isReconciling() == false)
        #expect(try await Self.allDocuments().count == 1)
    }

    // MARK: - Planning

    @Test(arguments: Self.fileSystemDates)
    func planLeavesAnUnchangedSnapshotAlone(modified: Date) async throws {
        let items = [Self.item(id: 1,
                               path: "/Archive/2024/2024-01-02--rechnung__bill.pdf",
                               isTagged: true,
                               contentModificationDate: modified)]
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(items, root: archiveRoot, rootURL: Self.archiveURL, generation: generation)

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
        let indexer = Self.makeIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(items, root: archiveRoot, rootURL: Self.archiveURL, generation: generation)
        let before = try await Self.allDocuments()

        // Any row the second snapshot rewrites aborts its transaction, and the reported error
        // fails this test - a silent full rewrite cannot pass. `indexerStates` counts too: the
        // flag is already false, and rewriting it invalidates every observation of that table.
        try await database.write { db in
            try #sql("""
                CREATE TRIGGER "reject_updates" BEFORE UPDATE ON "documents"
                BEGIN SELECT RAISE(ABORT, 'no updates'); END
                """)
                .execute(db)
            try #sql("""
                CREATE TRIGGER "reject_state_updates" BEFORE UPDATE ON "indexerStates"
                BEGIN SELECT RAISE(ABORT, 'no updates'); END
                """)
                .execute(db)
        }
        defer {
            try? database.write { db in
                try #sql(#"DROP TRIGGER "reject_updates""#).execute(db)
                try #sql(#"DROP TRIGGER "reject_state_updates""#).execute(db)
            }
        }

        await indexer.reconcile(items, root: archiveRoot, rootURL: Self.archiveURL, generation: generation)

        #expect(try await Self.allDocuments() == before)
    }

    /// This is the one signal that tells "the download never started" apart from "it started but
    /// never reported progress" - it has to fire even though the file itself is unremarkable.
    @Test
    func planReportsADownloadStatusChange() async throws {
        let path = "/Archive/2024/2024-01-02--rechnung__bill.pdf"
        let existingDocument = await Document.make(
            from: Self.item(id: 1, path: path, isTagged: true, downloadStatus: 0),
            rootKey: archiveRoot)
        let items = [Self.item(id: 1, path: path, isTagged: true, downloadStatus: 0.5)]
        var documents: [Document.ID: Document] = [:]
        for item in items {
            documents[item.id] = await Document.make(from: item, rootKey: archiveRoot)
        }

        let plan = ArchiveIndexer.plan(items: items, existing: [1: existingDocument], root: archiveRoot, documents: documents)

        #expect(plan.downloadStatusChanges == [ArchiveIndexer.DownloadStatusChange(id: 1, old: 0, new: 0.5)])
    }

    /// The whole point of splitting parsing out of `plan`: an item whose stored row already
    /// matches folder, url and tag state has nothing a re-parse could change.
    @Test
    func itemsNeedingParseSkipsAnUnchangedItemButKeepsAMovedOne() async throws {
        let unchangedPath = "/Archive/2024/2024-01-02--rechnung__bill.pdf"
        let unchangedItem = Self.item(id: 1, path: unchangedPath, isTagged: true, downloadStatus: 0)
        let unchangedRow = await Document.make(from: unchangedItem, rootKey: archiveRoot)

        let movedItem = Self.item(id: 2, path: "/Archive/2024/2024-02-02--new-name__bill.pdf", isTagged: true)
        let movedExistingRow = await Document.make(
            from: Self.item(id: 2, path: "/Archive/2024/2024-02-02--old-name__bill.pdf", isTagged: true),
            rootKey: archiveRoot)

        let items = [
            // Only the download status differs - `plan` updates this in place, no re-parse needed.
            Self.item(id: 1, path: unchangedPath, isTagged: true, downloadStatus: 1),
            movedItem
        ]
        let existing: [Document.ID: Document] = [1: unchangedRow, 2: movedExistingRow]

        let toParse = ArchiveIndexer.itemsNeedingParse(items: items, existing: existing, root: archiveRoot)

        #expect(toParse.map(\.id) == [2])
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

    private static let archiveURL = URL(filePath: "/Archive")
    private static let localURL = URL(filePath: "/Local")

    /// Both roots are reachable; of the documents only the paths in `existingPaths` still exist.
    private static func makeIndexer(existingPaths: Set<String> = []) -> ArchiveIndexer {
        let reachable = [archiveURL, localURL].map { $0.path(percentEncoded: false) }
        return ArchiveIndexer { url in
            let path = url.path(percentEncoded: false)
            return reachable.contains(path) || existingPaths.contains(path)
        }
    }

    /// Sub-millisecond, like the dates the file system reports.
    private static let fileSystemDate = Date(timeIntervalSince1970: 1_759_576_537.427_740_3)

    /// Only some milliseconds are exactly representable, so one sample proves nothing: every one of
    /// these has to survive the write and the read unchanged, or the guard never fires for it.
    private static let fileSystemDates = [
        fileSystemDate,
        Date(timeIntervalSince1970: 1_319_726_468.037_133_2),
        Date(timeIntervalSince1970: 1_191_032_025.027_238_8),
        Date(timeIntervalSince1970: 1_493_337_490.719_618_8),
        Date(timeIntervalSince1970: 1_700_000_000.123_456_7),
        Date(timeIntervalSince1970: -1_000_000.500_1),
        Date(timeIntervalSince1970: 0)
    ]

    private static func item(id: Document.ID,
                             path: String,
                             isTagged: Bool,
                             size: Double = 100,
                             downloadStatus: Double = 1,
                             creationDate: Date? = nil,
                             contentModificationDate: Date? = fileSystemDate) -> DocumentInformation {
        DocumentInformation(id: id,
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

    /// Extracted text, index state and AI suggestion - what a wrong deletion would throw away.
    private static func addDerivedData(for id: Document.ID) async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try DocumentText.insert { DocumentText(rowid: id, body: "text") }.execute(db)
            try DocumentIndexState.insert {
                DocumentIndexState(documentID: id,
                                   sourceSize: 100,
                                   sourceModificationDate: nil,
                                   indexedAt: Date(timeIntervalSince1970: 0),
                                   outcome: .indexed,
                                   characterCount: 4,
                                   extractorVersion: DocumentIndexState.currentExtractorVersion)
            }
            .execute(db)
            try DocumentSuggestion.insert {
                DocumentSuggestion(documentID: id, specification: "spec", tags: ["x"], createdAt: Date(timeIntervalSince1970: 0))
            }
            .execute(db)
        }
    }

    private static func hasIndexState(_ id: Document.ID) async throws -> Bool {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try DocumentIndexState.where { $0.documentID.eq(id) }.fetchCount(db) > 0
        }
    }

    private static func hasSuggestion(_ id: Document.ID) async throws -> Bool {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try DocumentSuggestion.where { $0.documentID.eq(id) }.fetchCount(db) > 0
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
