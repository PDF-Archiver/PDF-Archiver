//
//  Queries.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Foundation
import SQLiteData

/// One filter the user added to the archive search field.
nonisolated public enum SearchToken: Hashable, Identifiable, Sendable {
    case tag(String)
    case year(Int)
    case text(String)

    public var id: String { description }

    public var description: String {
        switch self {
        case .tag(let tag):
            "tag: \(tag)"

        case .year(let year):
            "year: \(year)"

        case .text(let text):
            "text: \(text)"
        }
    }

    public var value: String {
        switch self {
        case .tag(let tag):
            return tag

        case .year(let year):
            return "\(year)"

        case .text(let text):
            return text
        }
    }
}

/// One row of the archive list: the document plus what a free-text search found in it.
@Selection
nonisolated public struct ArchiveSearchRow: Identifiable, Equatable, Sendable {
    public let document: Document
    public let isFilenameHit: Bool
    /// FTS5 snippet with `[`/`]` around the matched terms, `nil` for a filename-only hit.
    public let snippet: String?

    public var id: Document.ID { document.id }
}

/// A year and how many documents fall into it.
@Selection
nonisolated public struct YearCount: Equatable, Sendable {
    public let year: Int
    public let count: Int
}

/// A tag and how many documents carry it.
@Selection
nonisolated public struct TagUsage: Equatable, Sendable {
    public let tag: String
    public let count: Int
}

extension Document {
    public static let tagged = Self.where(\.isTagged).order { $0.date.desc() }
    public static let inbox = Self.where { !$0.isTagged }.order { $0.date.desc() }
    public static let untaggedCount = Self.where { !$0.isTagged }.count()

    /// Tagged documents filtered by tokens, newest first and never capped - the complete list.
    public static func list(tokens: [SearchToken]) -> Select<ArchiveSearchRow, Document, ()> {
        Self.where { documents in
            documents.isTagged
        }
        .where { documents in
            for token in tokens {
                switch token {
                case .tag(let tag):
                    DocumentTag
                        .where { $0.documentID.eq(documents.id).and($0.tag.eq(tag)) }
                        .exists()

                case .year(let year):
                    documents.year.eq(year)

                case .text(let text):
                    documents.filename.like("%\(Self.escapedForLike(text))%", escape: "\\")
                }
            }
        }
        .order { $0.date.desc() }
        .select { documents in
            ArchiveSearchRow.Columns(document: documents, isFilenameHit: #sql("0"), snippet: #sql("NULL"))
        }
    }

    /// Tagged documents matching free text in the filename or the content, ranked and capped.
    ///
    /// Raw SQL for two reasons the DSL cannot express: `leftJoin(statement)` merges the joined
    /// statement's `WHERE` into the main query, so a DSL left join against a `MATCH` subselect
    /// silently becomes an inner filter and drops every filename-only hit; and `snippet()`
    /// tokenises the stored body of every row it is evaluated for, so it has to run after the cap.
    public static func rankedSearch(_ query: ArchiveSearchQuery) -> some Statement<ArchiveSearchRow> {
        let likePattern = query.likePattern
        // FTS5 rejects an empty MATCH even behind a false condition, so the content half is
        // omitted from the statement rather than disabled inside it.
        let content = query.ftsQuery.map { Self.contentFragments(matching: $0) } ?? Self.emptyContentFragments

        return #sql(
            """
            WITH "ranked" AS (
              SELECT d."id" AS "id",
                     (d."filename" LIKE \(bind: likePattern) ESCAPE '\\') AS "isFilenameHit",
                     \(content.rank) AS "rank",
                     d."date" AS "date"
              FROM \(Document.self) AS d
              \(content.join)
              WHERE d."isTagged" = 1
                \(query.tokenPredicates)
                AND (d."filename" LIKE \(bind: likePattern) ESCAPE '\\'\(content.orClause))
              ORDER BY "isFilenameHit" DESC, COALESCE("rank", 0) ASC, d."date" DESC
              LIMIT \(bind: resultLimit)
            )
            SELECT \(Document.columns), r."isFilenameHit", \(content.snippet) AS "snippet"
            FROM "ranked" AS r
            JOIN \(Document.self) ON \(Document.id) = r."id"
            ORDER BY r."isFilenameHit" DESC, COALESCE(r."rank", 0) ASC, \(Document.date) DESC
            """,
            as: ArchiveSearchRow.self
        )
    }

    private struct ContentFragments {
        let rank: QueryFragment
        let join: QueryFragment
        let orClause: QueryFragment
        let snippet: QueryFragment
    }

    private static let emptyContentFragments = ContentFragments(rank: "NULL", join: "", orClause: "", snippet: "NULL")

    private static func contentFragments(matching ftsQuery: String) -> ContentFragments {
        ContentFragments(
            rank: #"t."rank""#,
            join: """
                LEFT JOIN (
                  SELECT "rowid", "rank" FROM \(DocumentText.self) WHERE \(DocumentText.self) MATCH \(bind: ftsQuery)
                ) AS t ON t."rowid" = d."id"
                """,
            orClause: #" OR t."rowid" IS NOT NULL"#,
            snippet: """
                (SELECT snippet(\(DocumentText.self), 0, '\(raw: snippetOpenMarker)', '\(raw: snippetCloseMarker)', '…', 12)
                   FROM \(DocumentText.self)
                  WHERE "rowid" = r."id" AND \(DocumentText.self) MATCH \(bind: ftsQuery))
                """
        )
    }

    /// A ranked search is capped; the token-filtered list is not.
    public static let resultLimit = 200

    /// The snippet markers the view turns into styling. Chosen so real document text cannot
    /// contain them by accident.
    public static let snippetOpenMarker = "\u{2}"
    public static let snippetCloseMarker = "\u{3}"

    /// The archive slice handed to the model as tag vocabulary and description examples.
    ///
    /// Capped so a huge archive cannot be materialised in one array; the prompt only keeps the 30
    /// most frequent tags and 40 newest descriptions anyway.
    public static func aiContext(limit: Int = 2_000) -> some SelectStatementOf<Document> {
        Self.tagged.limit(limit)
    }

    public static func yearCounts(taggedOnly: Bool) -> Select<YearCount, Document, ()> {
        Self.where { documents in
            if taggedOnly {
                documents.isTagged
            }
        }
        .group(by: \.year)
        .order { $0.year.desc() }
        .select { documents in
            YearCount.Columns(year: documents.year, count: documents.count())
        }
    }

    /// Escapes the three characters SQLite's `LIKE` gives a meaning to, for use with `ESCAPE '\'`.
    public static func escapedForLike(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}

extension DocumentTag {
    /// Tags ordered by how often they are used, optionally narrowed to a prefix.
    public static func counts(prefix: String? = nil, taggedOnly: Bool = false, limit: Int) -> Select<TagUsage, DocumentTag, ()> {
        Self.where { documentTags in
            if let prefix, !prefix.isEmpty {
                documentTags.tag.like("\(Document.escapedForLike(prefix))%", escape: "\\")
            }
        }
        .where { documentTags in
            if taggedOnly {
                Document.where { $0.id.eq(documentTags.documentID).and($0.isTagged) }.exists()
            }
        }
        .group(by: \.tag)
        .order { ($0.documentID.count().desc(), $0.tag) }
        .select { documentTags in
            TagUsage.Columns(tag: documentTags.tag, count: documentTags.documentID.count())
        }
        .limit(limit)
    }

    /// Tags that appear on documents already carrying every tag in `tags`, most used first.
    public static func cooccurring(with tags: Set<String>, limit: Int) -> Select<TagUsage, DocumentTag, ()> {
        let sortedTags = tags.sorted()
        return Self.where { documentTags in
            documentTags.tag.notIn(sortedTags)
        }
        .where { documentTags in
            for tag in sortedTags {
                Self.where { $0.documentID.eq(documentTags.documentID).and($0.tag.eq(tag)) }.exists()
            }
        }
        .group(by: \.tag)
        .order { ($0.documentID.count().desc(), $0.tag) }
        .select { documentTags in
            TagUsage.Columns(tag: documentTags.tag, count: documentTags.documentID.count())
        }
        .limit(limit)
    }
}
