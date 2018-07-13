//
//  DateParser.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 13.06.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

struct DateParser {
    var formats = [
        "yyyy-MM-dd": "\\d{4}-\\d{2}-\\d{2}",
        "yyyyMMdd": "\\d{8}"
    ]
    let dateFormatter = DateFormatter()

    func parse(_ dateIn: String) -> Date? {
        for format in formats {
            if var dateRaw = regexMatches(for: format.value, in: dateIn) {
                self.dateFormatter.dateFormat = format.key
                if let date = self.dateFormatter.date(from: String(dateRaw[0])) {
                    return date
                }
            }
        }

        return nil
    }
}
