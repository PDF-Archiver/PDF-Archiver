//
//  ArchiveStoreTaggedTests.swift
//  ArchiverLib
//

import ArchiverModels
import Dependencies
import Foundation
import Testing

@testable import ArchiverStore

/// `isTagged` and `Document.parseFilename` have to agree: a name the parser gives no
/// specification must not reach the archive as a tagged document with an empty one.
@Suite
struct ArchiveStoreTaggedTests {
    private let archiveFolder: URL
    private let yearFolder: URL

    init() throws {
        let root = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        archiveFolder = root.appending(component: "Archive")
        yearFolder = archiveFolder.appending(component: "2024")
        try FileManager.default.createDirectory(at: archiveFolder.appending(component: "untagged"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: yearFolder, withIntermediateDirectories: true)
    }

    @Test(.timeLimit(.minutes(1)))
    func aNameWithTwoDoubleDashesIsNotTagged() async throws {
        let wellFormed = yearFolder.appending(component: "2024-01-01--a__tag.pdf")
        let twoDashes = yearFolder.appending(component: "2024-01-01--a--b__tag.pdf")
        try Data("%PDF".utf8).write(to: wellFormed)
        try Data("%PDF".utf8).write(to: twoDashes)

        let (snapshots, continuation) = AsyncStream.makeStream(of: [DocumentInformation].self)
        await withDependencies {
            $0.archiveIndexer.setObservedRoots = { _ in 0 }
            $0.archiveIndexer.reconcile = { items, _, _, _ in continuation.yield(items) }
        } operation: {
            let store = ArchiveStore()
            await store.update(archiveFolder: archiveFolder, untaggedFolders: [archiveFolder.appending(component: "untagged")])
        }

        var iterator = snapshots.makeAsyncIterator()
        let items = try #require(await iterator.next())
        let tagged = Dictionary(uniqueKeysWithValues: items.map { ($0.url.lastPathComponent, $0.isTagged) })

        #expect(tagged[wellFormed.lastPathComponent] == true)
        #expect(tagged[twoDashes.lastPathComponent] == false)
    }
}
