//
//  Schema.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Dependencies
import Foundation
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
    public var lastReconciledAt: Date?
    public var lastTextRunStartedAt: Date?
    public var lastTextRunFinishedAt: Date?
    public var rebuildRequested: Bool

    public init(id: Int = 1,
                isReconciling: Bool = false,
                lastReconciledAt: Date? = nil,
                lastTextRunStartedAt: Date? = nil,
                lastTextRunFinishedAt: Date? = nil,
                rebuildRequested: Bool = false) {
        self.id = id
        self.isReconciling = isReconciling
        self.lastReconciledAt = lastReconciledAt
        self.lastTextRunStartedAt = lastTextRunStartedAt
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

    /// Raising this re-extracts every document, for a fix that changes what the text looks like.
    public static let currentExtractorVersion = 1
}

extension DependencyValues {
    /// Opens the read model and brings its schema up to date.
    ///
    /// Must run before the first dependency access - `defaultDatabase` may be prepared only once
    /// per process.
    public mutating func bootstrapDatabase() throws {
        let database = try SQLiteData.defaultDatabase()
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("Create 'documents', 'documentTags' and 'indexerStates' tables") { db in
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
                  "lastReconciledAt" TEXT,
                  "lastTextRunStartedAt" TEXT,
                  "lastTextRunFinishedAt" TEXT,
                  "rebuildRequested" INTEGER NOT NULL DEFAULT 0
                ) STRICT
                """)
                .execute(db)
            try #sql(#"INSERT INTO "indexerStates" ("id") VALUES (1)"#).execute(db)
        }
        migrator.registerMigration("Create 'documentTexts' full-text index and 'documentIndexStates' table") { db in
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
        }
        try migrator.migrate(database)

        // A crash mid-scan would otherwise leave the progress indicator up forever.
        try database.write { db in
            try IndexerState
                .find(IndexerState.singletonID)
                .update { $0.isReconciling = false }
                .execute(db)
        }

        defaultDatabase = database
    }
}
