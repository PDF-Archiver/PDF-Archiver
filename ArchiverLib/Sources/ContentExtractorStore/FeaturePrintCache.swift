//
//  FeaturePrintCache.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 13.09.26.
//

import ArchiverModels
import Foundation

/// Where a document's Vision feature print is remembered between launches - stage 3's visual
/// fallback for retrieval when a scan's OCR yield is too thin to rank on
/// (`docs/retrieval-augmented-tagging-concept.md`).
///
/// A seam like `SuggestionCache`: this module must not depend on `ArchiverDatabase`, so the
/// vector lives in the app's SQLite read model; tests keep it in memory.
nonisolated public struct FeaturePrintCache: Sendable {
    /// The only revision `GenerateImageFeaturePrintRequest` currently supports, as the integer an
    /// `Entry` is stamped with. Shared between the writer (`PDFOCREngine`/`DocumentProcessor`) and
    /// the reader (`VisualNeighbourFinder`) so both agree on what "current" means without either
    /// depending on the other's module.
    public static let currentRevision = 1

    public struct Entry: Equatable, Sendable {
        public let documentID: Document.ID
        /// A `FeaturePrintObservation`, `PropertyListEncoder`-encoded. Vision exposes no public
        /// initializer that rebuilds one from its raw vector alone, so the entry keeps the whole
        /// `Codable` round trip rather than just `observation.data`.
        public let encodedObservation: Data
        /// `GenerateImageFeaturePrintRequest.Revision` as an integer (1 = `.revision2`, the only
        /// case today). `distance(to:)` throws across revisions, so a stale entry must be told
        /// apart from a current one without decoding it first.
        public let revision: Int

        public init(documentID: Document.ID, encodedObservation: Data, revision: Int) {
            self.documentID = documentID
            self.encodedObservation = encodedObservation
            self.revision = revision
        }
    }

    public var load: @Sendable (Document.ID) async -> Entry?
    public var save: @Sendable (Entry) async -> Void
    public var clear: @Sendable () async -> Void

    public init(load: @escaping @Sendable (Document.ID) async -> Entry?,
                save: @escaping @Sendable (Entry) async -> Void,
                clear: @escaping @Sendable () async -> Void) {
        self.load = load
        self.save = save
        self.clear = clear
    }

    /// Nothing is remembered. Stage 3 degrades to no visual fallback, same as an empty cache.
    public static let unavailable = FeaturePrintCache(load: { _ in nil }, save: { _ in }, clear: {})

    /// A fresh cache that lives as long as the returned value.
    public static func inMemory() -> FeaturePrintCache {
        let storage = Storage()
        return FeaturePrintCache(
            load: { await storage.entry(for: $0) },
            save: { await storage.insert($0) },
            clear: { await storage.removeAll() }
        )
    }

    private actor Storage {
        private var entries: [Document.ID: Entry] = [:]

        func entry(for id: Document.ID) -> Entry? { entries[id] }
        func insert(_ entry: Entry) { entries[entry.documentID] = entry }
        func removeAll() { entries.removeAll() }
    }
}
