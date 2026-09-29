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
    func anUpdateBeforeTheInitialSnapshotIsHeldBack() {
        var assembler = SnapshotAssembler()

        let early = assembler.applyUpdate(added: [], updated: [Self.item(id: 1)], removed: [])
        let initial = assembler.applyInitial([Self.item(id: 1), Self.item(id: 2), Self.item(id: 3)])

        #expect(early == nil)
        #expect(initial.map(\.id).sorted() == [1, 2, 3])
    }

    @Test
    func anEarlyRemovalOfAnItemMissingFromTheResultsStaysOut() {
        var assembler = SnapshotAssembler()

        _ = assembler.applyUpdate(added: [Self.item(id: 9)], updated: [], removed: [])
        _ = assembler.applyUpdate(added: [], updated: [], removed: [Self.item(id: 9)])
        let initial = assembler.applyInitial([Self.item(id: 1)])

        #expect(initial.map(\.id) == [1])
    }

    @Test
    func anUpdateAfterTheInitialSnapshotIsMergedAndSentOnlyOnce() {
        var assembler = SnapshotAssembler()
        _ = assembler.applyInitial([Self.item(id: 1), Self.item(id: 2)])

        let merged = assembler.applyUpdate(added: [Self.item(id: 3)], updated: [], removed: [Self.item(id: 1)])
        let repeated = assembler.applyUpdate(added: [Self.item(id: 3)], updated: [], removed: [])

        #expect(merged?.map(\.id).sorted() == [2, 3])
        #expect(repeated == nil)
    }

    private static func item(id: Int) -> DocumentInformation {
        DocumentInformation(id: id,
                            url: URL(filePath: "/Archive/2024/2024-01-0\(id)--doc__x.pdf"),
                            isTagged: true,
                            sizeInBytes: 100,
                            downloadStatus: 1,
                            creationDate: nil,
                            contentModificationDate: nil)
    }
}
