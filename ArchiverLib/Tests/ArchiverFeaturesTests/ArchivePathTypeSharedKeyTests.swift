//
//  ArchivePathTypeSharedKeyTests.swift
//  ArchiverLib
//

import ArchiverModels
import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing

struct ArchivePathTypeSharedKeyTests {
    @Test
    func keepsTheWrittenStorageTypeAfterItsOwnChangeNotification() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            @Shared(.archivePathType) var archivePathType: StorageType?
            $archivePathType.withLock { $0 = .iCloudDrive }

            #expect(archivePathType == .iCloudDrive)
        }
    }

    @Test
    func picksUpAChangeWrittenStraightToTheStore() throws {
        let store = UserDefaults.inMemory
        try withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            @SharedReader(.archivePathType) var archivePathType: StorageType?
            store.set(try JSONEncoder().encode(StorageType.iCloudDrive), forKey: "archivePathType")

            #expect(archivePathType == .iCloudDrive)
        }
    }

    /// An archive on an external drive that is unmounted at launch fails to resolve once; the
    /// stored bookmark has to survive that, or the location is lost for good.
    @Test
    func aBookmarkThatFailsToResolveStaysStored() {
        let store = UserDefaults.inMemory
        let unresolvable = Data("not a bookmark".utf8)
        store.set(unresolvable, forKey: "archivePathType")

        withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            @SharedReader(.archivePathType) var archivePathType: StorageType?

            #expect(archivePathType == nil)
            #expect(store.object(forKey: "archivePathType") as? Data == unresolvable)
        }
    }
}
