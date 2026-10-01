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
}
