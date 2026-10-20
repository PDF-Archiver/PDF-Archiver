//
//  VisualNeighbourFinder.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 13.09.26.
//

import ArchiverModels
import Foundation

/// Where stage 3's visual fallback ranks come from, used only when text retrieval
/// (``NeighbourFinder``) finds nothing above the floor - a scan whose OCR yield is too thin to
/// retrieve on (`docs/retrieval-augmented-tagging-concept.md`).
///
/// A seam like `NeighbourFinder`: this module holds no Vision code, so the feature-print distance
/// ranking lives where both Vision and `ArchiverDatabase` are available.
nonisolated public struct VisualNeighbourFinder: Sendable {
    /// Ranked, tagged neighbours by feature-print distance, closest first. Empty when
    /// `documentID` has no cached feature print yet, or none of the tagged archive does.
    public var find: @Sendable (_ documentID: Document.ID, _ limit: Int) async -> [NeighbourFinder.Match]

    public init(find: @escaping @Sendable (_ documentID: Document.ID, _ limit: Int) async -> [NeighbourFinder.Match]) {
        self.find = find
    }

    /// No feature-print index available. The caller stays with whatever stage 1 already found
    /// (possibly nothing), exactly as if no visual neighbour had ever been computed.
    public static let unavailable = VisualNeighbourFinder(find: { _, _ in [] })
}
