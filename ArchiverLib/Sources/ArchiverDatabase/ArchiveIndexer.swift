//
//  ArchiveIndexer.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Dependencies
import Foundation
import SQLiteData

/// The single writer of the read model.
///
/// Folder providers deliver full snapshots per observed root; this actor diffs them against the
/// stored rows and writes the difference. Features only ever read.
public actor ArchiveIndexer {
    @Dependency(\.defaultDatabase) var database

    /// Roots whose provider was created, keyed logically - never by URL prefix.
    private var observedRoots: Set<String> = []
    private var currentGeneration = 0
    private var rootsAwaitingFirstSnapshot: Set<String> = []

    public init() {}

    /// Announces which roots are observed from now on and returns the generation snapshots must
    /// carry to be accepted.
    ///
    /// Rows of roots that are gone are deleted here, so a provider that fails to start cannot
    /// leave ghost documents behind.
    @discardableResult
    public func setObservedRoots(_ roots: [String]) -> Int {
        observedRoots = Set(roots)
        currentGeneration += 1
        rootsAwaitingFirstSnapshot = observedRoots

        let observedRoots = self.observedRoots
        withErrorReporting {
            try database.write { db in
                let staleIDs = try Document.where { $0.rootKey.notIn(observedRoots) }.select(\.id).fetchAll(db)
                try DocumentText.where { $0.rowid.in(staleIDs) }.delete().execute(db)
                try Document.where { $0.rootKey.notIn(observedRoots) }.delete().execute(db)
                try IndexerState
                    .find(IndexerState.singletonID)
                    .update { $0.isReconciling = !observedRoots.isEmpty }
                    .execute(db)
            }
        }
        return currentGeneration
    }

    /// Applies one full snapshot of `root`.
    ///
    /// Cancelled provider tasks still deliver buffered snapshots and actor jobs are not strictly
    /// FIFO, so a stale generation or an unobserved root is dropped before anything is written.
    public func reconcile(_ items: [DocumentSnapshotItem], root: String, generation: Int) async {
        guard isCurrent(root: root, generation: generation) else { return }

        var existing: [Document.ID: Document] = [:]
        let read = await withErrorReporting {
            try await database.read { db in
                try Document.where { $0.rootKey.eq(root) }.fetchAll(db)
            }
        }
        guard let read else { return }
        for row in read {
            existing[row.id] = row
        }

        // One row per id within this snapshot, last one wins: a duplicate would otherwise abort
        // the whole transaction. Duplicates across roots are not covered - see `isCurrent`.
        var items = items
        var seenIDs: Set<Document.ID> = []
        items = items.reversed().filter { item in
            guard seenIDs.insert(item.id).inserted else {
                reportIssue("Two files of root \(root) share document id \(item.id): \(item.url.path())")
                return false
            }
            return true
        }
        .reversed()

        var changed: [Document] = []
        var tagsToRewrite: Set<Document.ID> = []
        for item in items {
            guard let row = existing[item.id] else {
                changed.append(await Document.make(from: item, rootKey: root))
                tagsToRewrite.insert(item.id)
                continue
            }

            let sameFile = row.rootKey == root && row.url == item.url && row.isTagged == item.isTagged
            guard !(sameFile
                    && row.sizeInBytes == item.sizeInBytes
                    && row.downloadStatus == item.downloadStatus
                    && row.contentModificationDate == item.contentModificationDate) else { continue }

            guard sameFile else {
                // The name decides date, specification and tags, so a move re-parses; the id and
                // the indexed text survive.
                changed.append(await Document.make(from: item, rootKey: root))
                tagsToRewrite.insert(item.id)
                continue
            }

            var updated = row
            updated.sizeInBytes = item.sizeInBytes
            updated.downloadStatus = item.downloadStatus
            updated.contentModificationDate = item.contentModificationDate
            changed.append(updated)
        }

        let absentIDs = Set(existing.keys).subtracting(items.map(\.id))

        // Re-checked here, not only at entry: the actor is reentrant, and `setObservedRoots` runs
        // after every rescan, so the diff above may describe a generation that is already gone.
        guard isCurrent(root: root, generation: generation) else { return }

        do {
            try await write(changed: changed, tagsToRewrite: tagsToRewrite, absentIDs: absentIDs)
        } catch {
            reportIssue(error)
            await replaceRoot(root, with: items, generation: generation)
        }

        rootsAwaitingFirstSnapshot.remove(root)
        guard rootsAwaitingFirstSnapshot.isEmpty else { return }
        withErrorReporting {
            try database.write { db in
                try IndexerState
                    .find(IndexerState.singletonID)
                    .update { $0.isReconciling = false }
                    .execute(db)
            }
        }
    }

    // MARK: - Writing

    private func write(changed: [Document], tagsToRewrite: Set<Document.ID>, absentIDs: Set<Document.ID>) async throws {
        guard !changed.isEmpty || !absentIDs.isEmpty else { return }

        try await database.write { db in
            // Deletes run first: an insert or a URL update would otherwise collide with a row that
            // this very snapshot removes (a rename chain, an A<->B swap, a replaced file).
            if !absentIDs.isEmpty {
                // `documentTags` and `documentIndexStates` cascade; a virtual table cannot carry
                // a foreign key, so the FTS row goes explicitly.
                try DocumentText.where { $0.rowid.in(absentIDs) }.delete().execute(db)
                try Document.where { $0.id.in(absentIDs) }.delete().execute(db)
            }

            let storedIDs = try Set(
                Document.where { $0.id.in(changed.map(\.id)) }.select(\.id).fetchAll(db)
            )
            for document in changed where storedIDs.contains(document.id) {
                // Never update the primary key: `documentTags` references it and it is the FTS rowid.
                try Document
                    .find(document.id)
                    .update {
                        $0.rootKey = document.rootKey
                        $0.url = document.url
                        $0.filename = document.filename
                        $0.date = document.date
                        $0.year = document.year
                        $0.specification = document.specification
                        $0.tags = #bind(document.tags)
                        $0.isTagged = document.isTagged
                        $0.sizeInBytes = document.sizeInBytes
                        $0.downloadStatus = document.downloadStatus
                        $0.contentModificationDate = document.contentModificationDate
                    }
                    .execute(db)
            }
            let inserted = changed.filter { !storedIDs.contains($0.id) }
            if !inserted.isEmpty {
                try Document.insert { inserted }.execute(db)
            }

            let documentsWithNewTags = changed.filter { tagsToRewrite.contains($0.id) }
            try Self.rewriteTags(of: documentsWithNewTags, in: db)
        }
    }

    /// Whether a snapshot still describes the world the app is observing.
    ///
    /// `documentIdentifier` is unique per volume only, so two roots on different volumes can hand
    /// in the same id for different files. That is a known limitation of the identity itself
    /// (`docs/full-text-search-concept.md`, 6.3) and is not what this guard is about.
    private func isCurrent(root: String, generation: Int) -> Bool {
        generation == currentGeneration && observedRoots.contains(root)
    }

    /// Last resort after a failed write: the snapshot is authoritative, so the root is replaced
    /// wholesale rather than left in a half-applied state that every later snapshot inherits.
    func replaceRoot(_ root: String, with items: [DocumentSnapshotItem], generation: Int) async {
        var documents: [Document] = []
        for item in items {
            documents.append(await Document.make(from: item, rootKey: root))
        }
        let replacement = documents
        guard isCurrent(root: root, generation: generation) else { return }

        await withErrorReporting {
            try await database.write { db in
                let staleIDs = try Document.where { $0.rootKey.eq(root) }.select(\.id).fetchAll(db)
                try DocumentText.where { $0.rowid.in(staleIDs) }.delete().execute(db)
                try Document.where { $0.rootKey.eq(root) }.delete().execute(db)
                guard !replacement.isEmpty else { return }
                try Document.insert { replacement }.execute(db)
                try Self.rewriteTags(of: replacement, in: db)
            }
        }
    }

    private static func rewriteTags(of documents: [Document], in db: Database) throws {
        guard !documents.isEmpty else { return }
        try DocumentTag.where { $0.documentID.in(documents.map(\.id)) }.delete().execute(db)
        let tags = documents.flatMap { document in
            document.tags.sorted().map { DocumentTag(documentID: document.id, tag: $0) }
        }
        guard !tags.isEmpty else { return }
        try DocumentTag.insert { tags }.execute(db)
    }
}
