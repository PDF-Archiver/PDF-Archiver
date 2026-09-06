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
