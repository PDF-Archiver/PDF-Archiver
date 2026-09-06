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
