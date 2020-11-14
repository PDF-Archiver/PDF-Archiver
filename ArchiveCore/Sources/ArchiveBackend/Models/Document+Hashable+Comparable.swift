//
//  Document+Hashable+Comparable.swift
//  
//
//  Created by Julian Kahnert on 15.08.20.
//

extension Document: Hashable, Comparable {

    public static func < (lhs: Document, rhs: Document) -> Bool {

        // first: sort by date
        // second: sort by filename
        if let lhsdate = lhs.date,
            let rhsdate = rhs.date,
            lhsdate != rhsdate {
            return lhsdate < rhsdate
        }
        return lhs.path.absoluteString > rhs.path.absoluteString
    }

    public static func == (lhs: Document, rhs: Document) -> Bool {
        // "==" and hashValue must only compare the path to avoid duplicates in sets
        return lhs.id == rhs.id
    }

    // "==" and hashValue must only compare the path to avoid duplicates in sets
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
