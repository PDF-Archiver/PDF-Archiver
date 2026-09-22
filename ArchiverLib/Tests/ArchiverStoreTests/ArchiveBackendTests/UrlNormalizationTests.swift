//
//  UrlNormalizationTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Foundation
import Testing

@testable import ArchiverStore

@MainActor
struct UrlNormalizationTests {
    @Test
    func bothSpellingsOfTheSameFileNormalizeEqually() throws {
        let directory = URL(filePath: NSTemporaryDirectory()).appending(component: "normalization-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appending(component: "document.pdf")
        try Data("pdf".utf8).write(to: file)

        // The same file arrives as `/private/var/…` from one provider and `/var/…` from the other.
        let viaPrivate = URL(filePath: "/private" + file.path())
        #expect(viaPrivate.normalized() == file.normalized())
        #expect(viaPrivate.uniqueId() == file.uniqueId())
    }

    /// `resolvingSymlinksInPath()` only strips `/private` while the path exists on disk - a folder
    /// that has not been created yet (first launch, before `FileManager.createFolderIfNotExists`
    /// runs) would keep it and get a different root key than the same folder once files land in it.
    @Test
    func normalizedStripsPrivateEvenWhenThePathDoesNotExistYet() throws {
        let directory = URL(filePath: NSTemporaryDirectory()).appending(component: "normalization-\(UUID().uuidString)")
        let file = directory.appending(component: "does-not-exist-yet.pdf")

        let viaPrivate = URL(filePath: "/private" + file.path())
        #expect(viaPrivate.normalized() == file.normalized())
        #expect(viaPrivate.normalized().path().hasPrefix("/private") == false)
    }

    @Test
    func theIdFallbackIsStableAcrossCalls() throws {
        let path = "/Archive/2024/document.pdf"
        let sameSpelling = "/Archive/" + "2024" + "/document.pdf"

        #expect(path.stableHashValue == sameSpelling.stableHashValue)
        #expect(path.stableHashValue != "/Archive/2025/document.pdf".stableHashValue)
    }

    /// `ICloudFolderProvider.canHandle` and `ArchiveStore.getProvider` both reduce to this check -
    /// a stray `/private` on either side, on the raw or the already-normalized input, must not
    /// change the answer.
    @Test
    func isUnderMatchesRegardlessOfWhichSideCarriesAStrayPrivatePrefix() throws {
        let base = URL(filePath: "/var/mobile/Containers/Data/Application/ABC/Documents")
        let dirtyBase = URL(filePath: "/private/var/mobile/Containers/Data/Application/ABC/Documents")
        let child = base.appending(component: "untagged/document.pdf")
        let dirtyChild = URL(filePath: "/private" + child.path())

        #expect(child.isUnder(base))
        #expect(child.isUnder(dirtyBase))
        #expect(dirtyChild.isUnder(base))
        #expect(dirtyChild.isUnder(dirtyBase))

        // A sibling that merely shares a prefix is not a child.
        let sibling = URL(filePath: "/var/mobile/Containers/Data/Application/ABC/DocumentsOld/document.pdf")
        #expect(!sibling.isUnder(base))
    }
}
