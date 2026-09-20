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

    @Test
    func theIdFallbackIsStableAcrossCalls() throws {
        let path = "/Archive/2024/document.pdf"
        let sameSpelling = "/Archive/" + "2024" + "/document.pdf"

        #expect(path.stableHashValue == sameSpelling.stableHashValue)
        #expect(path.stableHashValue != "/Archive/2025/document.pdf".stableHashValue)
    }
}
