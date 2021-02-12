//
//  TagStore.swift
//  
//
//  Created by Julian Kahnert on 17.07.20.
//

import Combine
import Foundation

public final class TagStore {

    public static let shared = TagStore()

    @Published public private(set) var sortedTags: [String] = []
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

        ArchiveStore.shared.$documents
            .receive(on: DispatchQueue.global(qos: .background))
            .map(TagStore.documents2SortedTags(_:))
            .assign(to: &$sortedTags)
    }

    private static func documents2SortedTags(_ documents: [Document]) -> [String] {
        documents.filter { $0.taggingStatus == .tagged }
            .reduce(into: [:]) { ( counts: inout [String: Int], document: Document) in
                for tag in document.tags {
                    counts[tag, default: 0] += 1
                }
            }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                } else {
                    return lhs.value > rhs.value
                }
            }
            .map(\.key)
    }

    public func getAvailableTags(with searchTerms: [String]) -> Set<String> {

        // search in filename of the documents
        let filteredDocuments = ArchiveStore.shared.documents
            .filter { $0.taggingStatus == .tagged }
            .fuzzyMatchSorted(by: searchTerms)

        // get a set of all document tags
        let allDocumentTags = filteredDocuments.reduce(into: Set<String>()) { result, document in
            result.formUnion(document.tags)
        }

        let filteredTags: Set<String>
        if searchTerms.isEmpty {
            filteredTags = allDocumentTags
        } else {
            let lowercasedSearchTerms = searchTerms.map { $0.lowercased() }
            // filter the tags that match any searchTerm
            let filteredTagsArray = allDocumentTags
                .map { $0.lowercased() }
                .filter { tag in
                    lowercasedSearchTerms.contains { tag.contains($0) }
                }
            filteredTags = Set(filteredTagsArray)
        }

        return filteredTags
    }

    // MARK: Tag Index

    /// Get all tags that are used in other documents with the given `tagname`.
    /// - Parameter tagname: Given tag name.
    public func getSimilarTags(for tagname: String) -> Set<String> {
        return tagIndex[tagname]
    }
}
