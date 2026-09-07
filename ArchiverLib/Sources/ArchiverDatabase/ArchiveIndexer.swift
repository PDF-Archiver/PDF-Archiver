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
    /// Whether rows of roots this generation no longer observes still have to go.
    private var needsPrune = false
    /// When this process first held a text pass back for a running reconcile.
    private var textPassDeferredSince: Date?

    /// Rows per write transaction. Small enough that the newest documents are on screen within a
    /// fraction of a second, large enough not to pay a transaction per document.
    static let chunkSize = 250

    /// How long the text pass defers to a reconcile before it starts anyway.
    ///
    /// `rootsAwaitingFirstSnapshot` never empties when an observed root's provider stops yielding,
    /// and the text index would then not grow again for the rest of the process.
    static let reconcileDeadline: TimeInterval = 15 * 60

    public init() {}

    /// Announces which roots are observed from now on and returns the generation snapshots must
    /// carry to be accepted.
    ///
    /// Rows of roots that are gone are dropped in the first write of the new generation, never
    /// here: a provider that fails to start at launch is a transient condition, and the archive
    /// must stay visible until a live provider has reported what really exists.
    @discardableResult
    public func setObservedRoots(_ roots: [String]) -> Int {
        observedRoots = Set(roots)
        currentGeneration += 1
        rootsAwaitingFirstSnapshot = observedRoots
        needsPrune = !observedRoots.isEmpty

        let observedRoots = self.observedRoots
        withErrorReporting {
            try database.write { db in
                // The indicator means "nothing to show yet", so a warm launch and every rescan
                // after it render the stored rows instead of a spinner.
                let storedCount = try Document.where { $0.rootKey.in(observedRoots) }.fetchCount(db)
                try Self.setReconciling(storedCount == 0 && !observedRoots.isEmpty, in: db)
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
        guard let read else {
            // Nothing more arrives for this root now, and the raised flag would leave both the
            // progress indicator and the gated text pass waiting for a snapshot that never lands.
            clearReconciling()
            return
        }
        for row in read {
            existing[row.id] = row
        }

        let items = Self.deduplicated(items, root: root)
        let documents = await Self.makeDocuments(from: items, root: root)
        let plan = Self.plan(items: items, existing: existing, root: root, documents: documents)

        // Re-checked here, not only at entry: the actor is reentrant, and `setObservedRoots` runs
        // after every rescan, so the diff above may describe a generation that is already gone.
        guard isCurrent(root: root, generation: generation) else { return }

        do {
            try await removeAndPrune(absentIDs: plan.absentIDs)
            for start in stride(from: 0, to: plan.changed.count, by: Self.chunkSize) {
                guard isCurrent(root: root, generation: generation) else { return }
                let end = min(start + Self.chunkSize, plan.changed.count)
                try await write(Array(plan.changed[start..<end]), tagsToRewrite: plan.tagsToRewrite)
                // The rows written so far are already on screen; let anything else in before the
                // next chunk takes the writer connection again.
                await Task.yield()
            }
        } catch {
            reportIssue(error)
            // A cancelled write is not a failed one: rewriting the root from a snapshot the app has
            // stopped observing would undo what the next generation is about to write.
            guard !Task.isCancelled else { return }
            await replaceRoot(root, with: items, generation: generation)
        }

        rootsAwaitingFirstSnapshot.remove(root)
        guard rootsAwaitingFirstSnapshot.isEmpty else { return }
        clearReconciling()
    }

    /// Waits out a running reconcile, at most `timeout`; `false` means it is still running.
    ///
    /// A cold background launch enumerates the whole archive first, which takes minutes on a large
    /// iCloud archive - a caller that gives up earlier finds the text pass gated and indexes
    /// nothing.
    public func waitWhileReconciling(timeout: Duration) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { [database] in
                @FetchOne(IndexerState.find(IndexerState.singletonID).select(\.isReconciling), database: database)
                var isReconciling = true
                for await value in $isReconciling.publisher.values where !value {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let reconciled = await group.next() ?? false
            group.cancelAll()
            return reconciled
        }
    }

    /// Whether a text pass may take the writer connection now.
    ///
    /// Metadata first: the list is what the user is waiting for, and a text commit would queue
    /// ahead of a reconcile chunk on the single writer connection.
    func mayStartTextPass() async -> Bool {
        @Dependency(\.date.now) var now
        let isReconciling = await withErrorReporting {
            try await database.read { db in
                try IndexerState.find(IndexerState.singletonID).select(\.isReconciling).fetchOne(db) ?? false
            }
        }
        // A read that fails means writing would fail too, so the next scheduled run tries again.
        guard let isReconciling else { return false }
        guard isReconciling else {
            textPassDeferredSince = nil
            return true
        }
        guard let deferredSince = textPassDeferredSince else {
            textPassDeferredSince = now
            return false
        }
        return now.timeIntervalSince(deferredSince) >= Self.reconcileDeadline
    }

    /// Lowers the flag - what every path that stops reconciling still owes the UI.
    private func clearReconciling() {
        withErrorReporting {
            try database.write { db in
                try Self.setReconciling(false, in: db)
            }
        }
    }

    /// Writes the flag only when it changes: every snapshot passes through here, and an `UPDATE`
    /// that stores the value already there still invalidates every observation of `indexerStates`.
    private static func setReconciling(_ isReconciling: Bool, in db: Database) throws {
        let stored = try IndexerState
            .find(IndexerState.singletonID)
            .select(\.isReconciling)
            .fetchOne(db) ?? false
        guard stored != isReconciling else { return }
        try IndexerState
            .find(IndexerState.singletonID)
            .update { $0.isReconciling = isReconciling }
            .execute(db)
    }

    // MARK: - Planning

    /// What one snapshot changes about the stored rows of its root.
    struct ReconcilePlan: Equatable, Sendable {
        /// Newest first, so the top of the archive list is right as soon as the first rows land.
        var changed: [Document] = []
        var tagsToRewrite: Set<Document.ID> = []
        var absentIDs: Set<Document.ID> = []
    }

    /// Parses every snapshot item into the row it becomes.
    ///
    /// `@concurrent` for the same reason as `extractText`: under `NonisolatedNonsendingByDefault`
    /// thousands of filename parses would run on the indexer's executor and stall every other job.
    @concurrent
    nonisolated static func makeDocuments(from items: [DocumentSnapshotItem],
                                          root: String) async -> [Document.ID: Document] {
        var documents: [Document.ID: Document] = [:]
        documents.reserveCapacity(items.count)
        for item in items {
            documents[item.id] = await Document.make(from: item, rootKey: root)
        }
        return documents
    }

    /// One row per id within a snapshot, last one wins: a duplicate would otherwise abort the
    /// whole transaction. Duplicates across roots are not covered - see `isCurrent`.
    static func deduplicated(_ items: [DocumentSnapshotItem], root: String) -> [DocumentSnapshotItem] {
        var seenIDs: Set<Document.ID> = []
        return items.reversed().filter { item in
            guard seenIDs.insert(item.id).inserted else {
                reportIssue("Two files of root \(root) share document id \(item.id): \(item.url.path())")
                return false
            }
            return true
        }
        .reversed()
    }

    /// Diffs one snapshot against the stored rows.
    ///
    /// Pure, so "an unchanged snapshot changes nothing" is one assertion instead of an observation
    /// dance. `documents` carries the row each item's filename parses into.
    static func plan(items: [DocumentSnapshotItem],
                     existing: [Document.ID: Document],
                     root: String,
                     documents: [Document.ID: Document]) -> ReconcilePlan {
        var plan = ReconcilePlan()
        for item in items {
            if let row = existing[item.id], row.rootKey == root, row.url == item.url, row.isTagged == item.isTagged {
                guard !(row.sizeInBytes == item.sizeInBytes
                        && row.downloadStatus == item.downloadStatus
                        && row.contentModificationDate == item.contentModificationDate) else { continue }

                var updated = row
                updated.sizeInBytes = item.sizeInBytes
                updated.downloadStatus = item.downloadStatus
                updated.contentModificationDate = item.contentModificationDate
                plan.changed.append(updated)
                continue
            }

            // New, or moved: the name decides date, specification and tags, so it is re-parsed.
            // The id and the indexed text survive a move.
            guard let document = documents[item.id] else {
                reportIssue("No parsed row for document id \(item.id) of root \(root)")
                continue
            }
            plan.changed.append(document)
            plan.tagsToRewrite.insert(item.id)
        }

        plan.absentIDs = Set(existing.keys).subtracting(items.map(\.id))
        plan.changed.sort { $0.date > $1.date }
        return plan
    }

    // MARK: - Writing

    /// Everything this snapshot removes, in one transaction ahead of the chunks: an insert or a URL
    /// update would otherwise collide with a row that this very snapshot removes (a rename chain,
    /// an A<->B swap, a replaced file). Deletions are cheap, so they are never split.
    private func removeAndPrune(absentIDs: Set<Document.ID>) async throws {
        let rootsToKeep = needsPrune ? observedRoots : nil
        guard rootsToKeep != nil || !absentIDs.isEmpty else { return }
        let generation = currentGeneration

        try await database.write { db in
            if let rootsToKeep {
                try Self.pruneRoots(keeping: rootsToKeep, in: db)
            }
            guard !absentIDs.isEmpty else { return }
            // `documentTags` and `documentIndexStates` cascade; a virtual table cannot carry
            // a foreign key, so the FTS row goes explicitly.
            try DocumentText.where { $0.rowid.in(absentIDs) }.delete().execute(db)
            try Document.where { $0.id.in(absentIDs) }.delete().execute(db)
        }

        // `setObservedRoots` may have asked for a prune of its own across the write; clearing the
        // request here would drop it, and the vanished root's rows would stay until the next rescan.
        guard generation == currentGeneration else { return }
        needsPrune = false
    }

    private func write(_ changed: [Document], tagsToRewrite: Set<Document.ID>) async throws {
        guard !changed.isEmpty else { return }

        try await database.write { db in
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

    /// Drops the rows of every root outside `roots`.
    ///
    /// `roots` is never empty here: SQLite evaluates `x NOT IN ()` as true, so an empty set would
    /// delete the whole archive.
    private static func pruneRoots(keeping roots: Set<String>, in db: Database) throws {
        let staleIDs = try Document.where { $0.rootKey.notIn(roots) }.select(\.id).fetchAll(db)
        guard !staleIDs.isEmpty else { return }
        // `documentTags` and `documentIndexStates` cascade; a virtual table cannot carry a foreign
        // key, so the FTS row goes explicitly.
        try DocumentText.where { $0.rowid.in(staleIDs) }.delete().execute(db)
        try Document.where { $0.id.in(staleIDs) }.delete().execute(db)
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
