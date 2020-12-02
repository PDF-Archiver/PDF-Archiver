//
//  DateParser.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 20.11.18.
//

import Foundation

/// Parse several kinds of dates in a String.
public enum DateParser {

    public typealias ParserResult = (date: Date, rawDate: String)
    
    private struct FormatMapping {
        let format: String
        let regex: String
        let locale: Locale?
        let likelihood: Double
    }
    private typealias DateOrder = (first: Parts, second: Parts, third: Parts, likelihood: Double)
    private enum Parts {
        case year
        case month
        case day
    }

    private static let dateOrders: [DateOrder] = [
        (first: .day, second: .month, third: .year, likelihood: 0.6),
        (first: .year, second: .month, third: .day, likelihood: 0.6),
        (first: .year, second: .day, third: .month, likelihood: 0.3),
        (first: .month, second: .day, third: .year, likelihood: 0.1)
    ]
    private static let separator = "[\\.\\-\\_\\s\\/,]{0,3}"
    private static let mappings: [FormatMapping] = { return createMappings(for: locales) }()
    private static let locales = [Locale(identifier: "de_DE"), Locale(identifier: "en_US")]
    private static let minimumDate = Date(timeIntervalSince1970: 0)

    // MARK: - public API

    /// Get the first date from a raw string.
    ///
    /// - Parameter raw: Raw string which might contain a date.
    /// - Returns: The found date or nil if no date was found.
    public static func parse(_ raw: String) -> ParserResult? {
        return parse(raw, with: mappings)
    }

    /// Get the first date from a raw string for some given locales. This will generate new temporary mappings.
    ///
    /// - Parameters:
    /// - Parameter raw: Raw string which might contain a date.
    ///   - locales: Array which defines the order of locales that should be used for parsing.
    /// - Returns: The found date or nil if no date was found.
    public static func parse(_ raw: String, locales: [Locale]) -> ParserResult? {
        let mappings = createMappings(for: locales)
        return parse(raw, with: mappings)
    }

    // MARK: - internal date parser

    private static func parse(_ raw: String, with mappings: [FormatMapping]) -> ParserResult? {

        // use the super fast NSDataDetector first, e.g. for "yesterday"/"last monday"
        if let result = dateDetector(for: raw) {
            return result
        }
        
        // create a date parser
        let dateFormatter = DateFormatter()

        // only compare lowercased dates
        let lowercasedRaw = raw.lowercased()

        let resultQueue = DispatchQueue(label: "result")
        var result = [Int: ParserResult]()
        DispatchQueue.concurrentPerform(iterations: mappings.count) { idx in
            let localResult = resultQueue.sync { result }
            guard !localResult.keys.contains(where: { $0 < idx }) else { return }

            let mapping = mappings[idx]
            guard let rawDates = lowercasedRaw.capturedGroups(withRegex: "([\\D]+|^)(\(mapping.regex))([\\D]+|$)") else { return }

            // get raw date from captured groups
            let rawDate = String(rawDates[1])

            // cleanup all separators from the found string
            let foundString = String(rawDate)
                .replacingOccurrences(of: separator, with: "", options: .regularExpression)
                .lowercased()

            // setup the right format in the dateFormatter
            dateFormatter.dateFormat = mapping.format
            if let locale = mapping.locale {
                dateFormatter.locale = locale
            }

            // try to parse the found raw string
            if let date = dateFormatter.date(from: foundString),
                date > minimumDate {
                resultQueue.sync {
                    result[idx] = (date, rawDate)
                }
            }
        }

        return result.min(by: { $0.key < $1.key })?.value
    }

    // MARK: - helper functions

    private static func dateDetector(for text: String) -> ParserResult? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let result = detector.firstMatch(in: text, options: [], range: searchRange)

        if let date = result?.date,
           let rawRange = result?.range,
           let range = Range(rawRange, in: text) {
            return (date, String(text[range]))
        }
        return nil
    }

    private static func createMappings(for locales: [Locale]) -> [FormatMapping] {

        var monthMappings = [FormatMapping]()
        monthMappings.append(FormatMapping(format: "MM", regex: "(0[1-9]{1}|10|11|12)", locale: locales[0], likelihood: 0.6))

        let dateFormatter = DateFormatter()
        let otherMonthFormats = ["MMM", "MMMM"]
        for (index, locale) in locales.enumerated() {

            // setup the likelihood for this locale
            let likelihood = pow(0.5, Double(index))

            // use all month formats, e.g. "Jan." and "January"
            for otherMonthFormat in otherMonthFormats {
                var months = [String]()
                for month in 1...12 {
                    dateFormatter.dateFormat = "MM"
                    guard let date = dateFormatter.date(from: "\(month)") else { continue }

                    dateFormatter.locale = locale
                    dateFormatter.dateFormat = otherMonthFormat
                    months.append(dateFormatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: ""))
                }
                monthMappings.append(FormatMapping(format: otherMonthFormat, regex: "(\(months.joined(separator: "|")))", locale: locale, likelihood: likelihood))
            }
        }

        // real mapping
        var mappings = [(FormatMapping)]()
        for dateOrder in dateOrders {

            // create the cartesian product of all datepart variantes (e.g. yy or yyyy)
            let prod1 = product(part2mapping(dateOrder.first, monthMappings: monthMappings),
                                part2mapping(dateOrder.second, monthMappings: monthMappings))
            let prod2 = product(prod1,
                                part2mapping(dateOrder.third, monthMappings: monthMappings))

            // create the regular expressions and format for all products
            for row in prod2 {
                let element1 = row.0.0
                let element2 = row.0.1
                let element3 = row.1

                let regex = [element1.regex, element2.regex, element3.regex].joined(separator: separator)
                let format = element1.format + element2.format + element3.format
                let locale = [element1.locale, element2.locale, element3.locale].compactMap { $0 } .first
                let likelihood = ((element1.likelihood + element2.likelihood + element3.likelihood) / 3) * dateOrder.likelihood

                mappings.append(FormatMapping(format: format, regex: regex, locale: locale, likelihood: likelihood))
            }
        }

        // sort mappings by the likelihood
        mappings.sort { $0.likelihood > $1.likelihood }

        return mappings
    }

    private static func part2mapping(_ part: Parts, monthMappings: [FormatMapping]) -> [FormatMapping] {
        switch part {
        case .day:
            return [FormatMapping(format: "dd", regex: "(0{0,1}[1-9]{1}|[12]{1}\\d|3[01]{1})", locale: nil, likelihood: 1)]
        case .month:
            return monthMappings
        case .year:
            return [
                FormatMapping(format: "yyyy", regex: "((19|20)\\d{2})", locale: nil, likelihood: 0.9),
                FormatMapping(format: "yy", regex: "(\\d{2})", locale: nil, likelihood: 0.1)
            ]
        }
    }

    // Source: http://www.figure.ink/blog/2017/7/30/lazy-permutations-in-swift
    // swiftlint:disable identifier_name
    private static func product<X, Y>(_ xs: X, _ ys: Y) -> [(X.Element, Y.Element)] where X: Collection, Y: Collection {
        var orderedPairs: [(X.Element, Y.Element)] = []
        for x in xs {
            for y in ys {
                orderedPairs.append((x, y))
            }
        }
        return orderedPairs
    }
}
