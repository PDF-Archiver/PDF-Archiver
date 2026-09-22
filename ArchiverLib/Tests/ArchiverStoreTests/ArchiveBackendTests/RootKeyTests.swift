//
//  RootKeyTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 21.09.26.
//

import Foundation
import Testing

@testable import ArchiverStore

@Suite
struct RootKeyTests {
    /// Before `normalized()` was made existence-independent, a folder queried before it was ever
    /// created kept a stray `/private` and got a different root key than the same folder once
    /// files landed in it - `pruneRoots` would then delete the real root's rows on the next rescan.
    @Test
    func rootKeyIsTheSameBeforeAndAfterTheFolderIsCreated() throws {
        let root = URL(filePath: NSTemporaryDirectory()).appending(component: "rootkey-\(UUID().uuidString)")
        let archiveFolder = root.appending(component: "Archive")
        let dirtyArchiveFolder = URL(filePath: "/private" + archiveFolder.path())

        let keyBeforeCreation = RootKey.of(dirtyArchiveFolder)

        try FileManager.default.createDirectory(at: archiveFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let keyAfterCreation = RootKey.of(dirtyArchiveFolder)

        #expect(keyBeforeCreation == keyAfterCreation)
    }
}
