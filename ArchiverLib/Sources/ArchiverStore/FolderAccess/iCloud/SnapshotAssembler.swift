//
//  SnapshotAssembler.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 29.09.26.
//

import ArchiverModels
import Foundation

/// Folds `NSMetadataQuery`'s events, in the order the query's queue posted them, into Folder Snapshots.
///
/// Nothing leaves before the Initial Snapshot: an update that arrives earlier describes only the
/// changed items, and a snapshot built from it would make every other document look deleted.
struct SnapshotAssembler {
    /// One notification of the query, already read on the query's queue: `NSMetadataItem` is not
    /// `Sendable` and must not travel to the consumer.
    enum Event: Sendable {
        case initialSnapshot([DocumentInformation])
        case update(added: [DocumentInformation], updated: [DocumentInformation], removed: [URL])

        /// The event's name in the log.
        var name: String {
            switch self {
            case .initialSnapshot: "initial"
            case .update: "update"
            }
        }
    }

    private var currentDocuments: [Int: DocumentInformation] = [:]
    /// `nil` until the Initial Snapshot went out.
    private var lastSent: [DocumentInformation]?

    /// Returns the Folder Snapshot to send for `event`, or `nil` when there is nothing new to send.
    mutating func apply(_ event: Event) -> [DocumentInformation]? {
        switch event {
        case .initialSnapshot(let results):
            currentDocuments = Dictionary(results.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        case let .update(added, updated, removed):
            for change in added + updated {
                currentDocuments[change.id] = change
            }
            let removed = Set(removed)
            currentDocuments = currentDocuments.filter { !removed.contains($0.value.url) }
            guard lastSent != nil else { return nil }
        }

        let documents = Array(currentDocuments.values)
        guard lastSent?.sorted() != documents.sorted() else { return nil }
        lastSent = documents
        return documents
    }
}
