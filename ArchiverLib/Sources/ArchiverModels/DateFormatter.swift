//
//  DateFormatter.swift
//
//
//  Created by Julian Kahnert on 09.09.20.
//

import Foundation

nonisolated public extension DateFormatter {

    nonisolated static let yyyyMMdd = DateFormatter.with("yyyy-MM-dd")

    fileprivate static func with(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        // Filenames are exchanged between devices: a Buddhist or Japanese device calendar would
        // write the year 2569 and read Gregorian names as such.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = template
        return formatter
    }
}
