//
//  TagStore.swift
//  
//
//  Created by Julian Kahnert on 17.07.20.
//

import Combine

public final class TagStore {

    public static let shared = TagStore()

    public private(set) var tagIndex = TagIndex<String>()
    private var tagCounts: [String: Int] = [:]
    private var disposables = Set<AnyCancellable>()

    private init() {
        ArchiveStore.shared.$documents
            .sink { documents in
                var tagIndex = TagIndex<String>()
                for document in documents {
                    tagIndex.add(document.tags)
                }
                self.tagIndex = tagIndex
            }
            .store(in: &disposables)
    }

    public func getAvailableTags(with searchterms: [String]) -> Set<String> {

        // search in filename of the documents
        let filteredDocuments = ArchiveStore.shared.documents.fuzzyMatchSorted(by: searchterms)

        // get a set of all document tags
        let allDocumentTags = filteredDocuments.reduce(into: Set<String>()) { result, document in
            result.formUnion(document.tags)
        }

        let filteredTags: Set<String>
        if searchterms.isEmpty {
            filteredTags = allDocumentTags
        } else {
            // filter the tags that match any searchterm
            filteredTags = allDocumentTags.filter { tag in
                searchterms.contains { tag.lowercased().contains($0.lowercased()) }
            }
        }

        return filteredTags
    }

    public func getSortedTags() -> [String] {
        let documents = ArchiveStore.shared.documents
        let tagCounts = documents.reduce(into: [:]) { ( counts: inout [String: Int], document: Document) in
            for tag in document.tags {
                counts[tag, default: 0] += 1
            }
        }

        return tagCounts.sorted { $0.value > $1.value }
            .map(\.key)
    }

    // MARK: Tag Index

    /// Get all tags that are used in other documents with the given `tagname`.
    /// - Parameter tagname: Given tag name.
    public func getSimilarTags(for tagname: String) -> Set<String> {
        return tagIndex[tagname]
    }
}
