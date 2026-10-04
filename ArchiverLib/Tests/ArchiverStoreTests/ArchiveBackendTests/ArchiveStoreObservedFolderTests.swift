//
//  ArchiveStoreObservedFolderTests.swift
//  ArchiverLib
//

#if os(macOS)
import Dependencies
import Foundation
import Sharing
import Testing

@testable import ArchiverStore

/// The observed folder is a provider of its own on the Mac. Every path that rebuilds the
/// providers, a storage-type change included, has to pick it up again.
@Suite
struct ArchiveStoreObservedFolderTests {
    private let archiveFolder: URL
    private let untaggedFolder: URL
    private let observedFolder: URL

    init() throws {
        let root = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        archiveFolder = root.appending(component: "Archive")
        untaggedFolder = archiveFolder.appending(component: "untagged")
        observedFolder = root.appending(component: "Observed")
        try FileManager.default.createDirectory(at: untaggedFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: observedFolder, withIntermediateDirectories: true)
    }

    @Test(.timeLimit(.minutes(1)))
    func reloadObservesTheArchiveAndTheObservedFolder() async throws {
        let announcedRoots = LockIsolated<[String]>([])

        await withDependencies {
            $0.defaultAppStorage = .inMemory
            $0.archiveIndexer.setObservedRoots = { roots in
                announcedRoots.setValue(roots)
                return 1
            }
            $0.archiveIndexer.reconcile = { _, _, _, _ in }
        } operation: {
            @Shared(.observedFolder) var observed: URL?
            $observed.withLock { $0 = observedFolder }

            let store = ArchiveStore()
            await store.reload(archiveFolder: archiveFolder, untaggedFolder: untaggedFolder)
        }

        #expect(announcedRoots.value.count == 2)
    }
}
#endif
