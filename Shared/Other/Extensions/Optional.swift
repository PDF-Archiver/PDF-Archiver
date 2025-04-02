//
//  Optional.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.12.24.
//

import OSLog

public extension Optional {
    func get(with log: Logger, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) throws -> Wrapped {
        guard let self else {
            log.error("Failed to get value (\(function, privacy: .public) \(file, privacy: .public): \(line, privacy: .public)")
            throw OptionalError.notFound
        }
        return self
    }
}

public enum OptionalError: String, Error {
    case notFound
}
