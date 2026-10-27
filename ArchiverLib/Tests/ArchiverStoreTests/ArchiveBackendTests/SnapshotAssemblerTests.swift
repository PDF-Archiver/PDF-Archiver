//
//  SnapshotAssemblerTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 29.09.26.
//

import ArchiverModels
import Foundation
import Testing

@testable import ArchiverStore

@Suite
struct SnapshotAssemblerTests {
    @Test
    func nothingIsSentBeforeTheInitialSnapshotAndItsResultsReplaceEarlierUpdates() {
        // The serial queue reads the Initial Snapshot after the update, so its results already hold that change.
        let earlierUpdate = Self.item(id: 3, downloadStatus: 0.5)
        let initialSnapshot = [Self.item(id: 1), Self.item(id: 3, downloadStatus: 1)]
        var assembler = SnapshotAssembler()

        #expect(assembler.apply(.update(added: [], updated: [earlierUpdate], removed: [])) == nil)
        #expect(assembler.apply(.initialSnapshot(initialSnapshot))?.sorted() == initialSnapshot.sorted())
    }

    @Test
    func theInitialSnapshotOutranksAnEarlierRemoval() {
        let snapshots = Self.snapshots(from: [
            .update(added: [Self.item(id: 9)], updated: [], removed: []),
            .update(added: [], updated: [], removed: [Self.item(id: 9).url]),
            .initialSnapshot([Self.item(id: 1)])
        ])

        #expect(snapshots == [[1]])
    }

    @Test
    func anUpdateAfterTheInitialSnapshotIsKept() {
        let snapshots = Self.snapshots(from: [
            .initialSnapshot([Self.item(id: 1), Self.item(id: 2)]),
            .update(added: [Self.item(id: 3)], updated: [], removed: [Self.item(id: 1).url])
        ])

        #expect(snapshots == [[1, 2], [2, 3]])
    }

    @Test
    func anIdenticalSnapshotIsNotSentTwice() {
        let snapshots = Self.snapshots(from: [
            .initialSnapshot([Self.item(id: 1), Self.item(id: 2)]),
            .update(added: [Self.item(id: 3)], updated: [], removed: []),
            .update(added: [], updated: [Self.item(id: 3)], removed: []),
            .update(added: [], updated: [], removed: [Self.item(id: 7).url])
        ])

        #expect(snapshots == [[1, 2], [1, 2, 3]])
    }

    /// The ids of every Folder Snapshot the assembler sends for `events`, in order.
    private static func snapshots(from events: [SnapshotAssembler.Event]) -> [[Int]] {
        var assembler = SnapshotAssembler()
        return events.compactMap { assembler.apply($0)?.map(\.id).sorted() }
    }

    private static func item(id: Int, downloadStatus: Double = 1) -> DocumentInformation {
        DocumentInformation(id: id,
                            url: URL(filePath: "/Archive/2024/2024-01-0\(id)--doc__x.pdf"),
                            isTagged: true,
                            sizeInBytes: 100,
                            downloadStatus: downloadStatus,
                            creationDate: nil,
                            contentModificationDate: nil)
    }
}
