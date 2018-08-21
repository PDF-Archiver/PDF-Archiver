//
//  DateParser.swift
//  PDFArchiverTests
//
//  Created by Julian Kahnert on 20.07.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import XCTest
@testable import PDFArchiver

class DateParserTests: XCTestCase {
    let dateParser = DateParser()

    func testDateFormats() {
        for rawDate in ["2010-05-12", "2010_05_12", "20100512"] {
            let out = self.dateParser.parse(rawDate)

            // date object
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.date(from: "2010-05-12")
            XCTAssertEqual(out?.date, date)

            // raw date
            XCTAssertEqual(out?.rawDate, rawDate)
        }
    }

    func testDateInvalidDates() {
        for rawDate in ["2010-13-12", "2010-04-31", "2010-13-13", "2010-04-31"] {
            let out = self.dateParser.parse(rawDate)
            XCTAssertNil(out)
            XCTAssertNil(out, "Invalid string '\(rawDate)' found, but string parsed: \(out!.date)")
        }
    }

    func testDateCompleteStrings() {
        for rawDate in ["das-hier-2010-05-12", "2010_05_12 test filename", "20100512 test filename"] {
            let out = self.dateParser.parse(rawDate)

            // date object
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.date(from: "2010-05-12")
            XCTAssertEqual(out?.date, date)
        }
    }

}
