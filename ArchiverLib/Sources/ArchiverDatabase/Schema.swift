//
//  Schema.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Dependencies
import Foundation
import Sharing
import SQLiteData

/// One tag of one document, derived from `Document.tags`.
///
/// A normal rowid table on purpose: SQLite's update hook does not fire for `WITHOUT ROWID`
/// tables, so an observation whose region is only this table would never refresh.
@Table
nonisolated public struct DocumentTag: Equatable, Sendable {
    public let documentID: Document.ID
    public let tag: String

    public init(documentID: Document.ID, tag: String) {
        self.documentID = documentID
        self.tag = tag
    }
}

/// The indexer's own bookkeeping - exactly one row, `id == 1`.
@Table
nonisolated public struct IndexerState: Equatable, Sendable, Identifiable {
    public let id: Int
    public var isReconciling: Bool
    public var lastTextRunFinishedAt: Date?
    /// Set by "Rebuild search index", cleared once a text run has caught up - it is what lets that
    /// one run afford a full `optimize`.
    public var rebuildRequested: Bool

    public init(id: Int = 1,
                isReconciling: Bool = false,
                lastTextRunFinishedAt: Date? = nil,
                rebuildRequested: Bool = false) {
        self.id = id
        self.isReconciling = isReconciling
        self.lastTextRunFinishedAt = lastTextRunFinishedAt
        self.rebuildRequested = rebuildRequested
    }

    /// The single row's primary key.
    public static let singletonID = 1
}

/// The extracted text of one document. The FTS5 table is the text store itself: with a single
/// writer there is nothing to mirror, so no `content=` option and no triggers.
@Table
nonisolated public struct DocumentText: FTS5, Identifiable, Equatable, Sendable {
    @Column(primaryKey: true) public let rowid: Document.ID
    public var id: Document.ID { rowid }
    public let body: String

    public init(rowid: Document.ID, body: String) {
        self.rowid = rowid
        self.body = body
    }
}

/// Text-extraction bookkeeping, one row per document that a run has looked at.
@Table
nonisolated public struct DocumentIndexState: Identifiable, Equatable, Sendable {
    public enum Outcome: String, QueryBindable, Sendable {
        case indexed
        case noText
        case unreadable
        case failed
    }

    @Column(primaryKey: true) public let documentID: Document.ID
    public var id: Document.ID { documentID }
    /// The size and date the extracted text was read from, never the row's current ones - an
    /// in-place rewrite during extraction must leave a mismatch the next run detects.
    public var sourceSize: Double
    public var sourceModificationDate: Date?
    public var indexedAt: Date
    public var outcome: Outcome?
    public var characterCount: Int
    public var extractorVersion: Int

    public init(documentID: Document.ID,
                sourceSize: Double,
                sourceModificationDate: Date?,
                indexedAt: Date,
                outcome: Outcome?,
                characterCount: Int,
                extractorVersion: Int) {
        self.documentID = documentID
        self.sourceSize = sourceSize
        self.sourceModificationDate = sourceModificationDate
        self.indexedAt = indexedAt
        self.outcome = outcome
        self.characterCount = characterCount
        self.extractorVersion = extractorVersion
    }

    /// Raising this re-extracts every document, for a fix that changes what the text looks like -
    /// the only path that re-reads a document without a text layer, apart from the file changing.
    public static let currentExtractorVersion = 1
}

/// What Apple Intelligence suggested for one document, remembered between launches.
@Table
nonisolated public struct DocumentSuggestion: Identifiable, Equatable, Sendable {
    @Column(primaryKey: true) public let documentID: Document.ID
    public var id: Document.ID { documentID }
    public var specification: String
    @Column(as: [String].JSONRepresentation.self) public var tags: [String]
    public var createdAt: Date
    public var modelVersion: Int

    public init(documentID: Document.ID,
                specification: String,
                tags: [String],
                createdAt: Date,
                modelVersion: Int = 1) {
        self.documentID = documentID
        self.specification = specification
        self.tags = tags
        self.createdAt = createdAt
        self.modelVersion = modelVersion
    }
}

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    /// `true` while the read model could not be opened at all.
    ///
    /// Stored rather than posted as an alert: `bootstrapDatabase()` runs in `App.init()`, where no
    /// view is listening yet - the search index settings screen reads it when it is shown.
    public static var searchIndexUnavailable: Self {
        Self[.appStorage("shared-search-index-unavailable"), default: false]
    }
}

extension DependencyValues {
    /// Opens the read model and brings its schema up to date.
    ///
    /// Must run before the first dependency access - `defaultDatabase` may be prepared only once
    /// per process.
    public mutating func bootstrapDatabase() throws {
        try bootstrapDatabase(path: nil)
    }

    /// `path` is the seam the recreate-on-failure test needs: SQLiteData derives the app's own
    /// location, which a test must not touch.
    mutating func bootstrapDatabase(path: String?) throws {
        @Shared(.searchIndexUnavailable) var searchIndexUnavailable

        do {
            let database = try ReadModel.open(at: path)

            // A crash mid-scan would otherwise leave the progress indicator up forever.
            try database.write { db in
                try IndexerState
                    .find(IndexerState.singletonID)
                    .update { $0.isReconciling = false }
                    .execute(db)
            }

            // Only on a change: every launch passes here, and a write wakes every observer.
            if searchIndexUnavailable {
                $searchIndexUnavailable.withLock { $0 = false }
            }
            defaultDatabase = database
        } catch {
            // `defaultDatabase` stays unset, so SQLiteData answers every query from a blank
            // in-memory database - without this flag the app would only look empty.
            $searchIndexUnavailable.withLock { $0 = true }
            throw error
        }
    }
}

/// Opening the read model file, separate from the dependency that stores the connection.
private enum ReadModel {
    /// Opens the database and migrates it, recreating the file if that migration fails.
    static func open(at path: String?) throws -> any DatabaseWriter {
        let migrator = makeMigrator()
        let database = try SQLiteData.defaultDatabase(path: path)
        do {
            try migrator.migrate(database)
            return database
        } catch {
            reportIssue(error)

            // Recreating is safe because every table is derived from the file system
            // (`docs/adr/0003-database-is-a-derived-read-model.md`): it costs one rescan, where a
            // database that cannot be migrated costs the index for good.
            try? database.close()  // best effort: the file is unlinked either way
            try removeFiles(of: database)
            let recreated = try SQLiteData.defaultDatabase(path: path)
            try migrator.migrate(recreated)
            return recreated
        }
    }

    /// Removes the database file and the `-wal` / `-shm` siblings SQLite keeps beside it.
    ///
    /// A `-wal` a crash left behind is exactly the state the fresh file must not inherit.
    private static func removeFiles(of database: any DatabaseWriter) throws {
        let path = fileURL(ofDatabaseAt: database.path).path(percentEncoded: false)
        let manager = FileManager.default
        for file in [path, path + "-wal", path + "-shm"] where manager.fileExists(atPath: file) {
            try manager.removeItem(atPath: file)
        }
    }

    /// GRDB reports the string the connection was opened with: `SQLiteData.defaultDatabase` builds
    /// that from `applicationSupportDirectory` as a `file://` URI, a test passes a plain path.
    private static func fileURL(ofDatabaseAt path: String) -> URL {
        guard let uri = URL(string: path), uri.isFileURL else { return URL(filePath: path) }
        return uri
    }

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        // The read model is derived (`docs/adr/0003-database-is-a-derived-read-model.md`), so a
        // schema change rebuilds it from the file system instead of carrying migration code.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("Create the read model") { db in
            try #sql("""
                CREATE TABLE "documents" (
                  "id" INTEGER PRIMARY KEY NOT NULL,
                  "rootKey" TEXT NOT NULL,
                  "url" TEXT NOT NULL,
                  "filename" TEXT NOT NULL,
                  "date" TEXT NOT NULL,
                  "year" INTEGER NOT NULL,
                  "specification" TEXT NOT NULL DEFAULT '',
                  "tags" TEXT NOT NULL DEFAULT '[]',
                  "isTagged" INTEGER NOT NULL DEFAULT 0,
                  "sizeInBytes" REAL NOT NULL DEFAULT 0,
                  "downloadStatus" REAL NOT NULL DEFAULT 0,
                  "contentModificationDate" TEXT
                ) STRICT
                """)
                .execute(db)
            try #sql(#"CREATE INDEX "index_documents_on_rootKey" ON "documents"("rootKey")"#).execute(db)
            try #sql(#"CREATE INDEX "index_documents_on_url" ON "documents"("url")"#).execute(db)
            try #sql(#"CREATE INDEX "index_documents_on_isTagged_date" ON "documents"("isTagged", "date")"#).execute(db)
            try #sql(#"CREATE INDEX "index_documents_on_year" ON "documents"("year")"#).execute(db)

            try #sql("""
                CREATE TABLE "documentTags" (
                  "documentID" INTEGER NOT NULL REFERENCES "documents"("id") ON DELETE CASCADE,
                  "tag" TEXT NOT NULL,
                  PRIMARY KEY ("documentID", "tag")
                ) STRICT
                """)
                .execute(db)
            try #sql(#"CREATE INDEX "index_documentTags_on_tag" ON "documentTags"("tag")"#).execute(db)

            try #sql("""
                CREATE TABLE "indexerStates" (
                  "id" INTEGER PRIMARY KEY NOT NULL CHECK ("id" = 1),
                  "isReconciling" INTEGER NOT NULL DEFAULT 0,
                  "lastTextRunFinishedAt" TEXT,
                  "rebuildRequested" INTEGER NOT NULL DEFAULT 0
                ) STRICT
                """)
                .execute(db)
            try #sql(#"INSERT INTO "indexerStates" ("id") VALUES (1)"#).execute(db)

            try #sql("""
                CREATE VIRTUAL TABLE "documentTexts" USING fts5(
                  "body",
                  tokenize = 'unicode61 remove_diacritics 2',
                  prefix = '2 3'
                )
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "documentIndexStates" (
                  "documentID" INTEGER PRIMARY KEY NOT NULL REFERENCES "documents"("id") ON DELETE CASCADE,
                  "sourceSize" REAL NOT NULL,
                  "sourceModificationDate" TEXT,
                  "indexedAt" TEXT NOT NULL,
                  "outcome" TEXT NOT NULL,
                  "characterCount" INTEGER NOT NULL DEFAULT 0,
                  "extractorVersion" INTEGER NOT NULL DEFAULT 1
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "documentSuggestions" (
                  "documentID" INTEGER PRIMARY KEY NOT NULL REFERENCES "documents"("id") ON DELETE CASCADE,
                  "specification" TEXT NOT NULL DEFAULT '',
                  "tags" TEXT NOT NULL DEFAULT '[]',
                  "createdAt" TEXT NOT NULL,
                  "modelVersion" INTEGER NOT NULL DEFAULT 1
                ) STRICT
                """)
                .execute(db)
        }
        return migrator
    }
}
