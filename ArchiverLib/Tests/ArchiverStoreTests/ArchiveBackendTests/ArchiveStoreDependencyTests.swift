//
//  ArchiveStoreDependencyTests.swift
//  ArchiverLib
//

import Foundation
import Testing

@testable import ArchiverStore

struct ArchiveStoreDependencyTests {
    /// The search index evicts without checking the storage type, so this guard is all that keeps a
    /// local archive's only copy on disk.
    @Test
    func evictionLeavesAFileOutsideICloudInPlace() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        try Data("%PDF".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try await ArchiveStoreDependency.liveValue.evictDocumentAt(url)

        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
