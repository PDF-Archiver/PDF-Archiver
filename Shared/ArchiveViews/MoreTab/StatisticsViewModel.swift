//
//  StatisticsViewModel.swift
//  
//
//  Created by Julian Kahnert on 27.12.20.
//

import Foundation

public struct StatisticsViewModel: Log {

    private let documents: [Document]
    public var topTags: [(String, Int)]
    public var topYears: [(String, Int)]

    public init(documents: [Document]) {
        self.documents = documents

        let taggedDocuments = documents.filter { $0.taggingStatus == .tagged }

        let tmpTopTags = taggedDocuments
            .map(\.tags)
            .reduce(into: [String: Int]()) { (counts, documentTags) in
                for documentTag in documentTags {
                    counts[documentTag, default: 0] += 1
                }
            }
            .sorted { $0.value > $1.value }
            .prefix(3)
        self.topTags = Array(tmpTopTags)

        let tmpTopYears = taggedDocuments
            .map(\.folder)
            .reduce(into: [String: Int]()) { (counts, year) in
                counts[year, default: 0] += 1
            }
            .sorted { $0.value > $1.value }
            .prefix(3)
        self.topYears = Array(tmpTopYears)
    }

    var taggedDocumentCount: Int {
        documents.filter { $0.taggingStatus == .tagged }
            .count
    }

    var untaggedDocumentCount: Int {
        documents.filter { $0.taggingStatus == .untagged }
            .count
    }
}

#if DEBUG
import Combine
import StoreKit

extension StatisticsViewModel {

    private class MockArchiveStoreAPI: ArchiveStoreAPI {
        var documents: [Document] { [] }
        var documentsPublisher: AnyPublisher<[Document], Never> {
            Just([]).eraseToAnyPublisher()
        }
        func update(archiveFolder: URL, untaggedFolders: [URL]) {}
        func archive(_ document: Document, slugify: Bool) throws {}
        func download(_ document: Document) throws {}
        func delete(_ document: Document) throws {}
        func getCreationDate(of url: URL) throws -> Date? { nil }
    }

    static var previewViewModel = StatisticsViewModel(documents: [Document]())
}
#endif
