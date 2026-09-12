//
//  TagScore.swift
//  ArchiverLib
//

import Foundation

/// Set comparison of the suggested tags against the tags the user actually filed
/// the document under.
///
/// An empty suggestion scores 0 rather than a vacuous 1: for this feature
/// suggesting nothing is a failure, not a perfectly precise answer.
public struct TagScore: Equatable, Sendable {
    public let precision: Double
    public let recall: Double
    public let f1Score: Double

    public init(suggested: Set<String>, expected: Set<String>) {
        if suggested.isEmpty, expected.isEmpty {
            precision = 1
            recall = 1
            f1Score = 1
            return
        }

        let matches = Double(suggested.intersection(expected).count)
        precision = suggested.isEmpty ? 0 : matches / Double(suggested.count)
        recall = expected.isEmpty ? 0 : matches / Double(expected.count)

        let sum = precision + recall
        f1Score = sum == 0 ? 0 : 2 * precision * recall / sum
    }
}
