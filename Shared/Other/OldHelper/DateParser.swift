//
//  DateParser.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 20.11.18.
//

import Combine
import Foundation

/// Parse several kinds of dates in a String.
enum DateParser: Log {

    struct ParserResult: Codable {
        let date: Date
        let rawDate: String
    }

    /// Get the first date from a raw string.
    ///
    /// - Parameter raw: Raw string which might contain a date.
    /// - Returns: The found date or nil if no date was found.
    static func parse(_ raw: String) -> ParserResult? {
        let input = String(raw.prefix(10))
        if let result = localParse(raw) {
            return result
        } else if let date = DateFormatter.yyyyMMdd.date(from: input) {
            return ParserResult(date: date, rawDate: input)
        } else if let date = DateFormatter.yyyyMMdd.date(from: input.replacingOccurrences(of: "_", with: "-")) {
            return ParserResult(date: date, rawDate: input)
        } else {
            return nil
        }
    }

    private static func localParse(_ raw: String) -> ParserResult? {
        let types: NSTextCheckingResult.CheckingType = .date
        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            Self.log.criticalAndAssert("Could not create NSDataDetector")
            return nil
        }
        let match = detector.firstMatch(in: raw, range: NSRange(location: 0, length: raw.count))

        guard let match = match,
              let date = match.date else {
                return nil
            }
        let rawDate = (raw as NSString).substring(with: match.range)

        return ParserResult(date: date, rawDate: rawDate)
    }
}
