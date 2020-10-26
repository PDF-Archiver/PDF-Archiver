//
//  DateParser.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 13.06.18.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import Foundation

struct DateParser {
    var formats = [
        "yyyy-MM-dd": "\\d{4}-\\d{2}-\\d{2}",
        "yyyy_MM_dd": "\\d{4}_\\d{2}_\\d{2}",
        "yyyyMMdd": "\\d{8}"
    ]
    let dateFormatter = DateFormatter()

    func parse(_ dateIn: String) -> (date: Date, rawDate: String)? {
        for format in formats {
            if let dateRaw = dateIn.capturedGroups(withRegex: "(\(format.value))") {
                self.dateFormatter.dateFormat = format.key
                if let date = self.dateFormatter.date(from: String(dateRaw[0])) {
                    return (date, String(dateRaw[0]))
                }
            }
        }

        return nil
    }
}
