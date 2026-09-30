//
//  SnapshotAssembler.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 29.09.26.
//

import ArchiverModels
import Foundation

/// Folds `NSMetadataQuery`'s initial result set and its later updates into full folder snapshots.
///
/// Nothing leaves before the initial result set: an update that arrives earlier describes only the
/// changed items, and a snapshot built from it would make every other document look deleted.
struct SnapshotAssembler {
    private var currentDocuments: [Int: DocumentInformation] = [:]
    /// `nil` until the initial snapshot went out.
    private var lastSent: [DocumentInformation]?

    /// Replaces everything with the complete result set and returns it as the first snapshot.
    mutating func applyInitial(_ results: [DocumentInformation]) -> [DocumentInformation] {
        currentDocuments = Dictionary(results.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let documents = Array(currentDocuments.values)
        lastSent = documents
        return documents
    }

    /// Merges an update; returns a snapshot only once the initial one went out and only if it
    /// differs from the last one sent.
    mutating func applyUpdate(added: [DocumentInformation],
                              updated: [DocumentInformation],
                              removed: [URL]) -> [DocumentInformation]? {
        for change in added + updated {
            currentDocuments[change.id] = change
        }
        let removed = Set(removed)
        currentDocuments = currentDocuments.filter { !removed.contains($0.value.url) }
        guard let lastSent else { return nil }
        let documents = Array(currentDocuments.values)
        guard lastSent.sorted() != documents.sorted() else { return nil }
        self.lastSent = documents
        return documents
    }
}
