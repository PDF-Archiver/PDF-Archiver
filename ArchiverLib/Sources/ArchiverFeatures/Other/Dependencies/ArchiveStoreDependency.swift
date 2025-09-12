//
//  ArchiveStoreDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Foundation

@DependencyClient
struct ArchiveStoreDependency {
    var documentChanges: @Sendable () async -> AsyncStream<[Document]> = { AsyncStream<[Document]> { $0.yield([]) } }
    var reloadDocuments: @Sendable () async throws -> Void
    var isLoading: @Sendable () async -> AsyncStream<Bool> = { AsyncStream<Bool> { $0.yield(false) } }
    var startDownloadOf: @Sendable (URL) async throws -> Void
    var deleteDocumentAt: @Sendable (URL) async throws -> Void
    var getTagSuggestionsFor: @Sendable (String) async -> [String] = { _ in [] }
    var getTagSuggestionsSimilarTo: @Sendable (Set<String>) async -> [String] = { _ in [] }
    var parseFilename: @Sendable (String) async -> (date: Date?, specification: String?, tagNames: [String]?) = { _ in (nil, nil, nil) }
    var saveDocument: @Sendable (Document, Bool) async throws -> Void
    var setArchiveStorageType: @Sendable (StorageType) async throws -> Void
}

extension ArchiveStoreDependency: TestDependencyKey {
    static let previewValue = Self(
        documentChanges: {
            AsyncStream { stream in
                Task {
//                    try! await Task.sleep(for: .seconds(1))
                    stream.yield([
                        .mock(url: .temporaryDirectory.appending(component: "file1.pdf"), specification: "document-specification-1", tags: Set(["tag1", "tag2"])),
                        .mock(url: .temporaryDirectory.appending(component: "file2.pdf"), specification: "document-specification-2", tags: Set(["tag1", "tag2"]), downloadStatus: 1),
                        .mock(url: .temporaryDirectory.appending(component: "file3.pdf"), specification: "document-specification-3", tags: Set(["tag1", "tag2"]), downloadStatus: 1),
                        .mock(url: .temporaryDirectory.appending(component: "file4.pdf"), specification: "document-specification-4", tags: Set(["tag1", "tag2"]), downloadStatus: 1)
                    ])
//                    try! await Task.sleep(for: .seconds(2))
//                    stream.yield([
//                        .mock(url: .temporaryDirectory.appending(component: "file1.pdf"), specification: "document-specification-1", tags: Set(["tag1", "tag2"]), downloadStatus: 0.5)
//                    ])
//                    try! await Task.sleep(for: .seconds(1))
//                    stream.yield([
//                        .mock(url: .temporaryDirectory.appending(component: "file1.pdf"), specification: "document-specification-1", tags: Set(["tag1", "tag2"]), downloadStatus: 0.75)
//                    ])
//                    try! await Task.sleep(for: .seconds(1))
//                    stream.yield([
//                        .mock(url: .temporaryDirectory.appending(component: "file1.pdf"), specification: "document-specification-1", tags: Set(["tag1", "tag2"]), downloadStatus: 1)
//                    ])
                }
            }
        },
        reloadDocuments: { },
        isLoading: { AsyncStream { $0.yield(false) } },
        startDownloadOf: { _ in },
        deleteDocumentAt: { _ in },
        getTagSuggestionsFor: { _ in [] },
        getTagSuggestionsSimilarTo: { _ in [] },
        parseFilename: { _ in (nil, nil, nil) },
        saveDocument: { _, _ in },
        setArchiveStorageType: { _ in }
    )

    static let testValue = Self()
}

extension ArchiveStoreDependency: DependencyKey {
    static let liveValue = ArchiveStoreDependency(
        documentChanges: {
            return await ArchiveStore.shared.documentsStream
        },
        reloadDocuments: {
            return try await ArchiveStore.shared.reloadArchiveDocuments()
        },
        isLoading: {
            return AsyncStream { stream in
                Task {
                    for await isLoading in await ArchiveStore.shared.isLoadingStream {
                        stream.yield(isLoading)
                    }
                }
            }
        },
        startDownloadOf: { url in
            try await ArchiveStore.shared.startDownload(of: url)
        },
        deleteDocumentAt: { url in
            try await ArchiveStore.shared.delete(url: url)
        },
        getTagSuggestionsFor: { tag in
            await ArchiveStore.shared.getTagSuggestions(for: tag)
        },
        getTagSuggestionsSimilarTo: { tags in
            await ArchiveStore.shared.getTagSuggestionsSimilar(to: tags)
        },
        parseFilename: { filename in
            await Document.parseFilename(filename)
        },
        saveDocument: { document, shouldUpdatePdfMetadata in
            try await ArchiveStore.shared.save(document, shouldUpdatePdfMetadata: shouldUpdatePdfMetadata)
        },
        setArchiveStorageType: { type in
            try await ArchiveStore.shared.update(with: type)
        }
    )
}

extension DependencyValues {
    var archiveStore: ArchiveStoreDependency {
        get { self[ArchiveStoreDependency.self] }
        set { self[ArchiveStoreDependency.self] = newValue }
    }
}
