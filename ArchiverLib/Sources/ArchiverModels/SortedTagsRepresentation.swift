//
//  SortedTagsRepresentation.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import Foundation
import StructuredQueries

/// Stores a `Set<String>` as a JSON array of its `sorted()` elements.
///
/// The stock `Set<String>.JSONRepresentation` encodes in hash order, which differs per process, so
/// the column text of an unchanged document would never compare equal across launches.
nonisolated public struct SortedTagsRepresentation: QueryBindable, QueryDecodable, QueryRepresentable {
    public var queryOutput: Set<String>

    public init(queryOutput: Set<String>) {
        self.queryOutput = queryOutput
    }

    public init?(queryBinding: QueryBinding) {
        guard case .text(let json) = queryBinding,
              let tags = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) else { return nil }
        self.init(queryOutput: Set(tags))
    }

    public var queryBinding: QueryBinding {
        do {
            let data = try JSONEncoder().encode(queryOutput.sorted())
            guard let json = String(bytes: data, encoding: .utf8) else {
                struct UnencodableTags: Error {}
                return .invalid(UnencodableTags())
            }
            return .text(json)
        } catch {
            return .invalid(error)
        }
    }

    public init(decoder: inout some QueryDecoder) throws {
        try self.init(queryOutput: Set([String].JSONRepresentation(decoder: &decoder).queryOutput))
    }
}
