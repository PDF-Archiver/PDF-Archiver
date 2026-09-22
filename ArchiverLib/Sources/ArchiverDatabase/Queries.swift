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

/// One retrieval hit for `Document.neighbours(matchingFTSQuery:excluding:limit:)`: a tagged
/// document plus how well its text matched, best (most negative) rank first.
@Selection
nonisolated public struct DocumentNeighbour: Equatable, Sendable {
    public let document: Document
    public let rank: Double
}

/// One tagged document's Vision feature print, for stage 3's visual nearest-neighbour scan.
@Selection
nonisolated public struct DocumentFeaturePrintRow: Equatable, Sendable {
    public let document: Document
    public let encodedObservation: Data
    public let revision: Int
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
        // A bound `false` guard is not constant-folded, so FTS5 still parses the empty MATCH next
        // to it and throws. The content half is omitted from the statement, not disabled in it.
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

    /// The *k* tagged documents whose text best matches `ftsQuery`, ranked by `bm25(documentTexts)`.
    ///
    /// Reuses `rankedSearch`'s join/rank shape; `ftsQuery` differs because the caller (a whole
    /// document's text, not a short typed phrase) OR-joins its terms via `DocumentText.orQuery(from:)` -
    /// see that function for why. `documentID` excludes the document being tagged, so a re-tag
    /// never retrieves itself as its own nearest neighbour.
    public static func neighbours(matchingFTSQuery ftsQuery: String, excluding documentID: Document.ID?, limit: Int) -> some Statement<DocumentNeighbour> {
        // Built as a fragment, not `(\(bind: documentID) IS NULL OR ...)`: binding an Optional
        // directly triggers a spurious "debug description" warning, and unwrapping here also
        // drops the always-true `IS NULL OR` branch when there is nothing to exclude.
        let exclusion: QueryFragment = documentID.map { "AND d.\"id\" != \(bind: $0)\n" } ?? ""

        return #sql(
            """
            WITH "ranked" AS (
              SELECT d."id" AS "id", t."rank" AS "rank"
              FROM \(Document.self) AS d
              JOIN \(DocumentText.self) AS t ON t."rowid" = d."id"
              WHERE d."isTagged" = 1
                \(exclusion)
                AND \(DocumentText.self) MATCH \(bind: ftsQuery)
              ORDER BY t."rank" ASC
              LIMIT \(bind: limit)
            )
            SELECT \(Document.columns), r."rank" AS "rank"
            FROM "ranked" AS r
            JOIN \(Document.self) ON \(Document.id) = r."id"
            ORDER BY r."rank" ASC
            """,
            as: DocumentNeighbour.self
        )
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

    /// Join + staleness filter shared by the pending-text query (`downloaded: true`) and the
    /// not-downloaded prefetch query (`downloaded: false`) - same staleness rule, opposite
    /// download-status side, so eviction and prefetch never fight over the same document.
    static func indexStateJoinAndFilter(downloaded: Bool) -> QueryFragment {
        let comparison: QueryFragment = downloaded ? ">= 1" : "< 1"
        return """
        LEFT JOIN \(DocumentIndexState.self) ON \(DocumentIndexState.documentID) = \(Document.id)
        WHERE \(Document.downloadStatus) \(comparison)
          AND (\(DocumentIndexState.documentID) IS NULL
               OR \(DocumentIndexState.sourceSize) != \(Document.sizeInBytes)
               OR \(DocumentIndexState.sourceModificationDate) IS NOT \(Document.contentModificationDate)
               OR \(DocumentIndexState.extractorVersion) < \(bind: DocumentIndexState.currentExtractorVersion))
        """
    }

    /// Documents that are not on this device yet and whose text is missing or stale - excludes a
    /// document this run already indexed and then evicted, so eviction and prefetch do not churn
    /// the same document back and forth. Inbox first, newest first.
    public static func notDownloaded(limit: Int) -> some Statement<Document> {
        #sql(
            """
            SELECT \(Document.columns)
            FROM \(Document.self)
            \(indexStateJoinAndFilter(downloaded: false))
            ORDER BY \(Document.isTagged) ASC, \(Document.date) DESC
            LIMIT \(bind: limit)
            """,
            as: Document.self
        )
    }

    /// Escapes the three characters SQLite's `LIKE` gives a meaning to, for use with `ESCAPE '\'`.
    public static func escapedForLike(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}

extension DocumentText {
    /// As much of the indexed body as the date and tag parsers are handed.
    public static func prefix(of id: Document.ID) -> some Statement<String> {
        #sql(
            """
            SELECT substr("body", 1, \(bind: Document.analysedTextLength))
            FROM \(DocumentText.self)
            WHERE "rowid" = \(bind: id)
            """,
            as: String.self
        )
    }

    /// Where a term ends. Control characters split rather than vanish: FTS5's tokenizer breaks
    /// the indexed body at a U+0000 too, so `IN\u{0}56998332` has to become the two terms it
    /// was indexed as - and leaving one inside a quoted term makes FTS5 reject the whole query.
    private static func isTermSeparator(_ character: Character) -> Bool {
        character.isWhitespace || character.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }

    /// Turns a whole document's text into an FTS5 `OR` query.
    ///
    /// Unlike `ArchiveSearchQuery.ftsQuery`'s implicit `AND` over a few deliberately typed words,
    /// a whole document's vocabulary should surface anything sharing *some* of it, not only
    /// documents containing every word - `bm25()` does the actual relevance ranking.
    ///
    /// - Returns: `nil` when no term clears `ArchiveSearchQuery.minimumContentTermLength` - a bound
    ///   empty `MATCH` still gets parsed by FTS5 and throws, so the caller must skip the query
    ///   entirely rather than run it with an empty string.
    public static func orQuery(from text: String) -> String? {
        let terms = Set(
            text
                .split(whereSeparator: isTermSeparator)
                .map(String.init)
                .filter { $0.count >= ArchiveSearchQuery.minimumContentTermLength }
        )
        guard !terms.isEmpty else { return nil }

        return terms
            .sorted()
            .map { term in
                // Doubling an embedded quote is how FTS5 escapes it inside a quoted string.
                let escaped = term.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }
            .joined(separator: " OR ")
    }
}

extension DocumentFeaturePrint {
    /// Every tagged document's feature print, for the visual fallback's in-memory
    /// nearest-neighbour scan.
    ///
    /// No vector index: at archive scale (thousands of documents) a linear scan plus
    /// `distance(to:)` is cheap enough that one is not warranted
    /// (`docs/retrieval-augmented-tagging-concept.md`). `documentID` excludes the document being
    /// tagged, mirroring `Document.neighbours(matchingFTSQuery:excluding:limit:)`.
    public static func taggedRows(excluding documentID: Document.ID?) -> some Statement<DocumentFeaturePrintRow> {
        // See `Document.neighbours` for why this is a fragment rather than an inline
        // `(\(bind: documentID) IS NULL OR ...)` bind of an Optional.
        let exclusion: QueryFragment = documentID.map { "AND \(Document.id) != \(bind: $0)\n" } ?? ""

        return #sql(
            """
            SELECT \(Document.columns), f."encodedObservation" AS "encodedObservation", f."revision" AS "revision"
            FROM \(DocumentFeaturePrint.self) AS f
            JOIN \(Document.self) ON \(Document.id) = f."documentID"
            WHERE \(Document.isTagged) = 1
              \(exclusion)
            """,
            as: DocumentFeaturePrintRow.self
        )
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
