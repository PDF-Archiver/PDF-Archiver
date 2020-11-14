//
//  DateFormatter.swift
//  
//
//  Created by Julian Kahnert on 09.09.20.
//

import Foundation

extension DateFormatter {
    static func with(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
