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
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = template
        return formatter
    }
}
