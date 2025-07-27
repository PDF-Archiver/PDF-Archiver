//
//  Sequence.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.12.24.
//
// Source: https://www.swiftbysundell.com/articles/async-and-concurrent-forEach-and-map/

extension Sequence {
    public func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
     }
}
