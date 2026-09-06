//
//  ArchiveSearchQuery.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Foundation
import SQLiteData

/// One archive search, normalised into the two forms SQLite understands.
///
/// FTS5 has its own query language: a hyphen, a colon or an odd number of quotes in raw user input
/// throws at runtime. Every term is therefore quoted, and the star is appended outside the quotes.
nonisolated public struct ArchiveSearchQuery: Equatable, Sendable {
    /// A single typed character searches filenames only - the `prefix = '2 3'` indexes start at two.
    private static let minimumContentTermLength = 2

    public let tokens: [SearchToken]
    /// What the user typed. The content half matches real words, so it keeps the spaces.
    public let text: String
    /// Slugified, exactly as the filename filter has always used it - archive filenames are
    /// slugified too, so `büro` has to become `buero` to match `…-buero__…`.
    public let slugifiedText: String
    public let includesContent: Bool

    public init(text: String, tokens: [SearchToken], includesContent: Bool) {
        self.tokens = tokens
        self.text = text
        self.slugifiedText = text.slugified(withSeparator: "-")
        self.includesContent = includesContent
    }

    public var hasFreeText: Bool {
        !slugifiedText.isEmpty
    }

    /// `LIKE` pattern for the filename half, with `%`, `_` and `\` escaped.
    public var likePattern: String {
        "%\(Document.escapedForLike(slugifiedText))%"
    }

    /// The token filters as a safe SQL fragment, written against the `d` alias of `documents`
    /// that `Document.rankedSearch` gives the table.
    var tokenPredicates: QueryFragment {
        var fragment = QueryFragment()
        for token in tokens {
            switch token {
            case .tag(let tag):
                fragment.append("""
                    AND EXISTS (SELECT 1 FROM \(DocumentTag.self)                     WHERE \(DocumentTag.documentID) = d."id" AND \(DocumentTag.tag) = \(bind: tag))

                    """)

            case .year(let year):
                fragment.append("""
                    AND d."year" = \(bind: year)

                    """)

            case .text(let text):
                fragment.append("""
                    AND d."filename" LIKE \(bind: "%\(Document.escapedForLike(text))%") ESCAPE '\\'

                    """)
            }
        }
        return fragment
    }

    /// The `MATCH` expression, or `nil` when the content half must not be joined.
    ///
    /// Every term gets the prefix star, not only the last one, so the result list does not shrink
    /// when a space is typed.
    public var ftsQuery: String? {
        guard includesContent else { return nil }
        let terms = text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { $0.count >= Self.minimumContentTermLength }
        guard !terms.isEmpty else { return nil }

        return terms
            .map { term in
                // Doubling an embedded quote is how FTS5 escapes it inside a quoted string.
                let escaped = term.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\"*"
            }
            .joined(separator: " ")
    }
}
