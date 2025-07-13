//
//  DateFormatter.swift
//  
//
//  Created by Julian Kahnert on 09.09.20.
//

import Foundation

let _formatter = DateFormatter.with("yyyy-MM-dd")
public extension DateFormatter {

    static var yyyyMMdd: DateFormatter {
        _formatter
    }

    fileprivate static func with(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = template
        return formatter
    }
}
