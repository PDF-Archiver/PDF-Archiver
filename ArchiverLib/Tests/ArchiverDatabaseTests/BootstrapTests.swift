//
//  BootstrapTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.09.26.
//

import ArchiverModels
import Dependencies
import DependenciesTestSupport
import Foundation
import GRDB
import Sharing
import SQLiteData
import Testing

@testable import ArchiverDatabase

@Suite
struct BootstrapTests {
    /// A database an older build wrote: the migration hits `CREATE TABLE "documents"` on a table
    /// that is already there, and the app used to end up on a blank in-memory database instead.
    @Test
    func recreatesADatabaseThatCannotBeMigrated() async throws {
        let directory = URL.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appending(component: "SQLiteData.db").path(percentEncoded: false)

        let stale = try DatabaseQueue(path: path)
        try await stale.write { db in
            try db.execute(sql: #"CREATE TABLE "documents" ("nonsense" TEXT)"#)
        }
        try stale.close()
        // Empty siblings, like the ones a crash leaves behind: SQLite reopens these very files, so
        // a different `-wal` afterwards is what proves they went with the database.
        for suffix in ["-wal", "-shm"] {
            #expect(FileManager.default.createFile(atPath: path + suffix, contents: nil))
        }
        let staleFileID = try Self.fileIdentifier(of: path)
        let staleWalID = try Self.fileIdentifier(of: path + "-wal")

        var opened: (any DatabaseWriter)?
        withKnownIssue("the failed migration is reported, not swallowed") {
            // `.live`, because `SQLiteData.defaultDatabase` ignores the path in a test context and
            // answers with a temporary pool - the file under test would never be opened.
            try withDependencies {
                $0.context = .live
            } operation: {
                try withDependencies { values in
                    try values.bootstrapDatabase(path: path)
                } operation: {
                    @Dependency(\.defaultDatabase) var database
                    opened = database
                }
            }
        }

        let database = try #require(opened, "the app must not fall back to an in-memory database")
        #expect(database.path == path)
        #expect(try Self.fileIdentifier(of: path) != staleFileID)
        #expect((try? Self.fileIdentifier(of: path + "-wal")) != staleWalID)

        // The current schema, not the stale one-column table.
        try await database.write { db in
            try Document.insert {
                Document(id: -1,
                         rootKey: "test",
                         url: URL(filePath: "/Archive/2024/2024-01-02--x__y.pdf"),
                         date: Date(timeIntervalSince1970: 0),
                         specification: "x",
                         tags: ["y"],
                         isTagged: true,
                         sizeInBytes: 1,
                         downloadStatus: 1)
            }
            .execute(db)
        }
        #expect(try await database.read { db in try Document.all.fetchCount(db) } == 1)
        #expect(try await database.read { db in
            try IndexerState.find(IndexerState.singletonID).fetchOne(db)
        } != nil)
    }

    /// Without the flag the app would run on SQLiteData's blank in-memory database and merely look
    /// like an empty archive.
    @Test
    func recordsTheFlagWhenTheReadModelCannotBeOpenedAtAll() throws {
        let directory = URL.temporaryDirectory.appending(component: UUID().uuidString)
        // Read-only, so SQLite cannot create the database or its `-wal` here.
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o500])
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appending(component: "SQLiteData.db").path(percentEncoded: false)

        let suiteName = UUID().uuidString
        let store = try #require(UserDefaults(suiteName: suiteName))
        defer { store.removePersistentDomain(forName: suiteName) }

        withDependencies {
            $0.context = .live
            $0.defaultAppStorage = store
        } operation: {
            #expect(throws: (any Error).self) {
                try withDependencies { values in
                    try values.bootstrapDatabase(path: path)
                } operation: { }
            }

            @Shared(.searchIndexUnavailable) var searchIndexUnavailable
            #expect(searchIndexUnavailable)
        }
    }

    /// Inode, so "the file was recreated" is a fact rather than a timestamp comparison.
    private static func fileIdentifier(of path: String) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        return try #require(attributes[.systemFileNumber] as? Int)
    }
}
