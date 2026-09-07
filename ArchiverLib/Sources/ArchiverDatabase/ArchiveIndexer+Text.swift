//
//  ArchiveIndexer+Text.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Dependencies
import Foundation
import PDFKit.PDFDocument
import SQLiteData

extension ArchiveIndexer {
    /// One pathological file must not fill the index on its own.
    static let maximumCharacterCount = 1_000_000

    /// Extracts and stores the text of documents whose index is missing or stale.
    ///
    /// Only ever called by the platform schedulers, never by a user action: this is the expensive
    /// half of indexing and runs on external power at background quality of service.
    public func indexPendingTexts(budget: Int) async {
        // Returns before any bookkeeping, so the next scheduled run repeats the attempt.
        guard await mayStartTextPass() else { return }

        let pending = await withErrorReporting {
            try await database.read { db in
                try Self.pendingDocuments(limit: budget).fetchAll(db)
            }
        }
        guard let pending, !pending.isEmpty else {
            await finishTextRun(indexedAnything: false)
            return
        }

        var indexedAnything = false
        for document in pending {
            guard !Task.isCancelled else { break }
            let text = await Self.extractText(from: document.url)

            // A cancelled parse returns partial or no text. Committing it would record an
            // outcome for the current size and date, and `pendingDocuments` would never offer
            // the document again until the file itself changes.
            guard !Task.isCancelled else { break }

            await commit(text: text, for: document)
            indexedAnything = true
            // A reconcile chunk arriving mid-run must not wait out the whole budget.
            await Task.yield()
        }

        await finishTextRun(indexedAnything: indexedAnything)
    }

    /// Truncates the whole read model, so "Rebuild search index" repairs ghost rows as well as a
    /// broken text index. The caller asks `ArchiveStore` to rescan afterwards.
    public func requestRebuild() async {
        await withErrorReporting {
            try await database.write { db in
                try DocumentText.delete().execute(db)
                try Document.delete().execute(db)
                try IndexerState
                    .find(IndexerState.singletonID)
                    .update { $0.rebuildRequested = true }
                    .execute(db)
            }
        }
    }

    // MARK: - Suggestions

    /// Remembers what the model suggested for one document.
    ///
    /// Routed through the indexer so it stays the read model's only writer
    /// (`docs/adr/0003-database-is-a-derived-read-model.md`); the suggestion is derived data like
    /// everything else and a rebuild drops it.
    public func saveSuggestion(documentID: Document.ID, specification: String, tags: [String]) async {
        @Dependency(\.date.now) var now
        await withErrorReporting {
            try await database.write { db in
                try DocumentSuggestion
                    .upsert {
                        DocumentSuggestion(documentID: documentID,
                                           specification: specification,
                                           tags: tags,
                                           createdAt: now)
                    }
                    .execute(db)
            }
        }
    }

    public func clearSuggestions() async {
        await withErrorReporting {
            try await database.write { db in
                try DocumentSuggestion.delete().execute(db)
            }
        }
    }

    // MARK: - Extraction

    /// Reads the text layer page by page.
    ///
    /// `@concurrent` is the point: under `NonisolatedNonsendingByDefault` an ordinary `async`
    /// helper would run on the indexer's executor and stall every reconcile behind a PDF parse.
    @concurrent
    nonisolated static func extractText(from url: URL) async -> String? {
        // Never through `NSFileCoordinator`: it blocks until an iCloud file is downloaded.
        guard let document = PDFDocument(url: url) else { return nil }

        var text = ""
        for index in 0..<document.pageCount {
            guard !Task.isCancelled else { return nil }
            // A synchronous closure, so it wraps the PDFKit calls rather than the async flow.
            autoreleasepool {
                text += document.page(at: index)?.string ?? ""
            }
            guard text.count < maximumCharacterCount else { break }
        }
        return text
    }

    // MARK: - Bookkeeping

    func commit(text: String?, for document: Document) async {
        @Dependency(\.date.now) var now

        let (outcome, body) = Self.classify(text)

        await withErrorReporting {
            try await database.write { db in
                // The file may have been deleted or rewritten while it was being parsed.
                guard let current = try Document.find(document.id).fetchOne(db),
                      current.sizeInBytes == document.sizeInBytes,
                      current.contentModificationDate == document.contentModificationDate else { return }

                // SQLite has no UPSERT for virtual tables, so a replacement is delete plus insert.
                try DocumentText.find(document.id).delete().execute(db)
                if let body {
                    try DocumentText.insert { DocumentText(rowid: document.id, body: body) }.execute(db)
                }

                try DocumentIndexState
                    .upsert {
                        DocumentIndexState(documentID: document.id,
                                           sourceSize: document.sizeInBytes,
                                           sourceModificationDate: document.contentModificationDate,
                                           indexedAt: now,
                                           outcome: outcome,
                                           characterCount: body?.count ?? 0,
                                           extractorVersion: DocumentIndexState.currentExtractorVersion)
                    }
                    .execute(db)
            }
        }
    }

    /// Mojibake would pollute every prefix query it happens to match, so it is recorded but not
    /// indexed; empty text means the document has no text layer yet.
    private static func classify(_ text: String?) -> (DocumentIndexState.Outcome, String?) {
        guard let text else { return (.failed, nil) }
        guard !text.isEmpty else { return (.noText, nil) }
        guard TextReadability.isReadable(text) else { return (.unreadable, nil) }
        return (.indexed, String(text.prefix(maximumCharacterCount)))
    }

    private func finishTextRun(indexedAnything: Bool) async {
        @Dependency(\.date.now) var now
        await withErrorReporting {
            try await database.write { db in
                if indexedAnything {
                    // Incremental: `optimize` merges every segment in one transaction and does not
                    // fit an expirable background budget.
                    try #sql(#"INSERT INTO "documentTexts"("documentTexts", "rank") VALUES ('merge', 16)"#).execute(db)
                }

                let isRebuilding = try IndexerState
                    .find(IndexerState.singletonID)
                    .select(\.rebuildRequested)
                    .fetchOne(db) ?? false
                let hasPendingWork = try Self.pendingCount().fetchOne(db) ?? 0 > 0

                // The one moment a full `optimize` is affordable: a rebuild has just written every
                // segment from scratch and there is nothing left to index.
                if isRebuilding, !hasPendingWork, !Task.isCancelled {
                    try #sql(#"INSERT INTO "documentTexts"("documentTexts", "rank") VALUES ('optimize', -1)"#).execute(db)
                }

                try IndexerState
                    .find(IndexerState.singletonID)
                    .update {
                        $0.lastTextRunFinishedAt = #bind(now)
                        $0.rebuildRequested = #bind(hasPendingWork && isRebuilding)
                    }
                    .execute(db)
            }
        }
    }

    /// How many documents are waiting. Backs a live `@Fetch`, so it must not decode the rows.
    static func pendingCount() -> some Statement<Int> {
        #sql(
            """
            SELECT count(*)
            FROM \(Document.self)
            \(pendingJoinAndFilter)
            """,
            as: Int.self
        )
    }

    /// Documents with no index state, a changed size or modification date, or an older extractor.
    /// Inbox first, newest first.
    static func pendingDocuments(limit: Int) -> some Statement<Document> {
        #sql(
            """
            SELECT \(Document.columns)
            FROM \(Document.self)
            \(pendingJoinAndFilter)
            ORDER BY \(Document.isTagged) ASC, \(Document.date) DESC
            LIMIT \(bind: limit)
            """,
            as: Document.self
        )
    }

    private static var pendingJoinAndFilter: QueryFragment {
        """
        LEFT JOIN \(DocumentIndexState.self) ON \(DocumentIndexState.documentID) = \(Document.id)
        WHERE \(Document.downloadStatus) >= 1
          AND (\(DocumentIndexState.documentID) IS NULL
               OR \(DocumentIndexState.sourceSize) != \(Document.sizeInBytes)
               OR \(DocumentIndexState.sourceModificationDate) IS NOT \(Document.contentModificationDate)
               OR \(DocumentIndexState.extractorVersion) < \(bind: DocumentIndexState.currentExtractorVersion))
        """
    }
}

/// How many documents a text run recorded under one outcome.
@Selection
nonisolated struct OutcomeCount: Equatable, Sendable {
    let outcome: DocumentIndexState.Outcome?
    let count: Int
}

extension DocumentIndexState {
    /// What the settings screen shows about the content index.
    ///
    /// `indexed + withoutText + failed` is what a run has already looked at, `pending` is what it
    /// looks at next and `notDownloaded` what it cannot look at yet. They do not sum to `total`,
    /// because a document that is not downloaded may still carry a state row from before.
    public struct Status: Equatable, Sendable {
        public var total = 0
        public var indexed = 0
        public var withoutText = 0
        public var failed = 0
        public var pending = 0
        public var notDownloaded = 0
        public var lastRun: Date?

        public init(total: Int = 0,
                    indexed: Int = 0,
                    withoutText: Int = 0,
                    failed: Int = 0,
                    pending: Int = 0,
                    notDownloaded: Int = 0,
                    lastRun: Date? = nil) {
            self.total = total
            self.indexed = indexed
            self.withoutText = withoutText
            self.failed = failed
            self.pending = pending
            self.notDownloaded = notDownloaded
            self.lastRun = lastRun
        }
    }

    public struct StatusRequest: FetchKeyRequest {
        public init() {}

        /// Counts only - this backs a live `@Fetch` and must never decode a document row.
        public func fetch(_ db: Database) throws -> Status {
            var status = Status(
                total: try Document.all.fetchCount(db),
                pending: try ArchiveIndexer.pendingCount().fetchOne(db) ?? 0,
                notDownloaded: try Document.where { $0.downloadStatus.lt(1) }.fetchCount(db),
                lastRun: try IndexerState
                    .find(IndexerState.singletonID)
                    .select(\.lastTextRunFinishedAt)
                    .fetchOne(db)
                    .flatMap(\.self)
            )

            let outcomes = try DocumentIndexState
                .group(by: \.outcome)
                .select { OutcomeCount.Columns(outcome: $0.outcome, count: $0.count()) }
                .fetchAll(db)
            for row in outcomes {
                switch row.outcome {
                case .indexed:
                    status.indexed = row.count

                case .noText, .unreadable:
                    status.withoutText += row.count

                case .failed:
                    status.failed = row.count

                case nil:
                    break
                }
            }
            return status
        }
    }
}
