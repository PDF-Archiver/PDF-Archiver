//
//  ArchiveStoreUpdateTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 13.09.26.
//

import Dependencies
import Foundation
import Testing

@testable import ArchiverStore

/// `update()` suspends while it stops providers, creates them, resolves their root keys and
/// announces them, so two calls interleave on the actor. A cold launch makes exactly that:
/// `ArchiveStore.shared` reloads, and the first `.active` scene phase reloads again.
@Suite
struct ArchiveStoreUpdateTests {
    private let archiveFolder: URL
    private let untaggedFolder: URL

    init() throws {
        let root = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        archiveFolder = root.appending(component: "Archive")
        untaggedFolder = archiveFolder.appending(component: "untagged")
        try FileManager.default.createDirectory(at: untaggedFolder, withIntermediateDirectories: true)
    }

    /// Two announcements mean the overtaken run superseded the generation of the run that is
    /// actually observing: the indexer then drops every snapshot that arrives, and the progress
    /// indicator never lowers again.
    @Test(.timeLimit(.minutes(1)))
    func onlyTheSurvivingUpdateAnnouncesItsRoots() async throws {
        let announced = LockIsolated<[Int]>([])
        let (forwarded, forwardedContinuation) = AsyncStream.makeStream(of: Int.self)

        await withDependencies {
            $0.archiveIndexer.setObservedRoots = { _ in
                announced.withValue { generations in
                    generations.append(generations.count + 1)
                    return generations.count
                }
            }
            $0.archiveIndexer.reconcile = { _, _, generation in
                forwardedContinuation.yield(generation)
            }
        } operation: {
            let store = ArchiveStore()
            async let first: Void = store.update(archiveFolder: archiveFolder, untaggedFolders: [untaggedFolder])
            async let second: Void = store.update(archiveFolder: archiveFolder, untaggedFolders: [untaggedFolder])
            _ = await (first, second)

            #expect(announced.value == [1])

            // The generation the surviving observation task carries is the one the indexer still
            // accepts - the snapshot reaches the read model instead of being dropped.
            var forwardedGenerations = forwarded.makeAsyncIterator()
            #expect(await forwardedGenerations.next() == 1)
        }
    }
}
