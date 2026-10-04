//
//  FolderProviderCollisionTests.swift
//  ArchiverLib
//

import Foundation
import Testing

@testable import ArchiverStore

/// An evicted iCloud document exists only as `.name.pdf.icloud`; tagging a document to that name
/// must not move over it.
@Suite
struct FolderProviderCollisionTests {
    private let root: URL
    private let destination: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        destination = root.appending(component: "2024").appending(component: "2024-01-01--a__tag.pdf")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let placeholder = destination.deletingLastPathComponent().appending(component: ".\(destination.lastPathComponent).icloud")
        try Data().write(to: placeholder)
    }

    @Test
    func renameRefusesADestinationThatExistsAsAnICloudPlaceholder() async throws {
        let source = root.appending(component: "source.pdf")
        try Data("%PDF".utf8).write(to: source)
        let provider = try await LocalFolderProvider(baseUrl: root)

        await #expect(throws: FolderProviderError.renameFailedFileAlreadyExists) {
            try await provider.rename(from: source, to: destination)
        }
        #expect(FileManager.default.fileExists(atPath: source.path()))
    }

    @Test
    func saveRefusesADestinationThatExistsAsAnICloudPlaceholder() async throws {
        let provider = try await LocalFolderProvider(baseUrl: root)

        await #expect(throws: FolderProviderError.renameFailedFileAlreadyExists) {
            try await provider.save(data: Data("%PDF".utf8), at: destination)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path()))
    }
}
