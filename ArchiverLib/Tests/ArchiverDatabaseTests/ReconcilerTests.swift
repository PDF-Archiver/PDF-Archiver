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
import SQLiteData
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
    func removesRowsOfARootThatIsNoLongerObserved() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-02--x__y.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)

        _ = await indexer.setObservedRoots(["anotherRoot"])

        #expect(try await Self.allDocuments().isEmpty)
    }

    @Test
    func aDuplicatedIdentifierDoesNotWedgeTheRoot() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile(
            [
                Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true),
                Self.item(id: 1, path: "/Archive/2024/2024-01-02--b__x.pdf", isTagged: true)
            ],
            root: archiveRoot,
            generation: generation
        )

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
    func replacingARootRecoversFromAFailedWrite() async throws {
        let indexer = ArchiveIndexer()
        let generation = await indexer.setObservedRoots([archiveRoot])
        await indexer.reconcile([Self.item(id: 1, path: "/Archive/2024/2024-01-01--a__x.pdf", isTagged: true)],
                                root: archiveRoot,
                                generation: generation)

        let replacement = Self.item(id: 2, path: "/Archive/2024/2024-01-02--b__y.pdf", isTagged: true)
        await indexer.replaceRoot(archiveRoot, with: [replacement])

        #expect(try await Self.document(1) == nil)
        #expect(try await Self.document(2)?.filename == "2024-01-02--b__y.pdf")
        #expect(try await Self.tags(of: 2) == ["y"])
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

    // MARK: - Helpers

    private static func item(id: Document.ID,
                             path: String,
                             isTagged: Bool,
                             size: Double = 100,
                             downloadStatus: Double = 1,
                             creationDate: Date? = nil,
                             contentModificationDate: Date? = nil) -> DocumentSnapshotItem {
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

    private static func isReconciling() async throws -> Bool {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try IndexerState.find(IndexerState.singletonID).select(\.isReconciling).fetchOne(db) ?? false
        }
    }
}
