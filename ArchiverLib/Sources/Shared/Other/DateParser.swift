//
//  DateParser.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 20.11.18.
//

import Combine
import Foundation

/// Parse several kinds of dates in a String.
public enum DateParser: Log {

    private struct ParserResult: Codable {
        let date: Date
        let rawDate: String
    }

    /// Get the first date from a raw string.
    ///
    /// - Parameter raw: Raw string which might contain a date.
    /// - Returns: The found date or nil if no date was found.
    public static func parse(_ raw: String) -> [Date] {
        let input = String(raw.prefix(10))
        let results = localParse(raw)
        if !results.isEmpty {
            let dates = results.map(\.date)
            let dateString = results.map { DateFormatter.yyyyMMdd.string(from: $0.date) }

            var uniqueUnorderedResults = Set<String>()
            return zip(dates, dateString)
                .filter { (_, dateString) in
                    uniqueUnorderedResults.insert(dateString).inserted
                }
                .map(\.0)
        } else if let date = DateFormatter.yyyyMMdd.date(from: input) {
            return [date]
        } else if let date = DateFormatter.yyyyMMdd.date(from: input.replacingOccurrences(of: "_", with: "-")) {
            return [date]
        } else {
            return []
        }
    }

    private static func localParse(_ raw: String) -> [ParserResult] {
        let types: NSTextCheckingResult.CheckingType = .date
        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            Self.log.criticalAndAssert("Could not create NSDataDetector")
            return []
        }

        // the NSDataDetector parses times as "today" Date so we filter out all dates that are today
        return detector.matches(in: raw, range: NSRange(location: 0, length: raw.count))
            .lazy
            .compactMap { match in
                guard let date = match.date,
                      !Calendar.current.isDate(date, inSameDayAs: Date()) else { return nil }

                let rawDate = (raw as NSString).substring(with: match.range)
                return ParserResult(date: date, rawDate: rawDate)
            }
    }
}
