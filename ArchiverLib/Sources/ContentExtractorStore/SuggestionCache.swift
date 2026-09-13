//
//  SuggestionCache.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Foundation

/// Where the model's suggestions are remembered between launches.
///
/// A seam rather than a store: the app keeps them in its SQLite read model, which this module must
/// not depend on, while tests and the evaluations keep them in memory.
nonisolated public struct SuggestionCache: Sendable {
    public struct Entry: Equatable, Sendable {
        public let documentID: Document.ID
        public let specification: String
        public let tags: [String]

        public init(documentID: Document.ID, specification: String, tags: [String]) {
            self.documentID = documentID
            self.specification = specification
            self.tags = tags
        }
    }

    public var load: @Sendable (Document.ID) async -> Entry?
    public var save: @Sendable (Entry) async -> Void
    public var clear: @Sendable () async -> Void
    public var count: @Sendable () async -> Int

    public init(load: @escaping @Sendable (Document.ID) async -> Entry?,
                save: @escaping @Sendable (Entry) async -> Void,
                clear: @escaping @Sendable () async -> Void,
                count: @escaping @Sendable () async -> Int) {
        self.load = load
        self.save = save
        self.clear = clear
        self.count = count
    }

    /// Nothing is remembered. The default, so a store built without a cache cannot silently reach
    /// for storage it was never given.
    public static let unavailable = SuggestionCache(load: { _ in nil }, save: { _ in }, clear: { }, count: { 0 })

    /// A fresh cache that lives as long as the returned value.
    public static func inMemory() -> SuggestionCache {
        let storage = Storage()
        return SuggestionCache(
            load: { await storage.entry(for: $0) },
            save: { await storage.insert($0) },
            clear: { await storage.removeAll() },
            count: { await storage.count() }
        )
    }

    private actor Storage {
        private var entries: [Document.ID: Entry] = [:]

        func entry(for id: Document.ID) -> Entry? { entries[id] }
        func insert(_ entry: Entry) { entries[entry.documentID] = entry }
        func removeAll() { entries.removeAll() }
        func count() -> Int { entries.count }
    }
}
