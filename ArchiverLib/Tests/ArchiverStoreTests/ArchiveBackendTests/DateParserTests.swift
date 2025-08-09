//
//  DateParser.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 30.11.18.
//

import PDFKit
import Testing

@testable import Shared

@MainActor
struct DateParserTests {

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    @Test
    func testParsingValidDate() async throws {

        // setup the raw string
        let hiddenDate = "20050201"
        let longText = """
        Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.
        At vero eos et accusam et justo duo dolores et ea rebum.
        Stet clita kasd gubergren,\(hiddenDate)no sea takimata sanctus est Lorem ipsum dolor sit amet.
        Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.
        At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.
        """
        let rawStringMapping = [
            "28.01.2019": dateFormatter.date(from: "2019-01-28"),
            "Jan 16, 2019": dateFormatter.date(from: "2019-01-16"),
//            "n16072018n": dateFormatter.date(from: "2018-07-16"),
//            "Berlin16072018test": dateFormatter.date(from: "2018-07-16"),
//            "Berlin16072018": dateFormatter.date(from: "2018-07-16"),
            "1.05.2015": dateFormatter.date(from: "2015-05-01"),
            "12.05.2015": dateFormatter.date(from: "2015-05-12"),
            "12-05-2015": dateFormatter.date(from: "2015-05-12"),
            "2015-05-12": dateFormatter.date(from: "2015-05-12"),
//            "2015-13-12": dateFormatter.date(from: "2015-12-13"),
            "1990_02_11": dateFormatter.date(from: "1990-02-11"),
            "20050301": dateFormatter.date(from: "2005-03-01"),
            "2010_05_12_15_17": dateFormatter.date(from: "2010-05-12"),
            "09/10/2018": dateFormatter.date(from: "2018-10-09"),
//            "nn09/10/2018nn": dateFormatter.date(from: "2018-10-09"),
//            "199002_11": dateFormatter.date(from: "1990-02-11"),
//            "12.05-2020": dateFormatter.date(from: "2020-05-12"),
            "12. Januar 2020": dateFormatter.date(from: "2020-01-12"),
            "2. Jan 2020": dateFormatter.date(from: "2020-01-02"),
            "23. Feb. 2020": dateFormatter.date(from: "2020-02-23"),
            "23. February 2020": dateFormatter.date(from: "2020-02-23"),
            "19. february 2020": dateFormatter.date(from: "2020-02-19"),
            "6. dec 2020": dateFormatter.date(from: "2020-12-06"),
            "24. December 2020": dateFormatter.date(from: "2020-12-24"),
            "December 25, 2020": dateFormatter.date(from: "2020-12-25"),
//            "05 01 18": dateFormatter.date(from: "2018-01-05"),
            longText: dateFormatter.date(from: "2005-02-01")
        ]

        for (raw, date) in rawStringMapping {

            // calculate
            let parsedOutput = DateParser.parse(raw)

            // assert
            if let parsedDate = parsedOutput.first {
                let expectedDate = try #require(date)
                #expect(Calendar.current.isDate(parsedDate, inSameDayAs: expectedDate), "Found parsed output: \(parsedOutput)")
            } else {
                Issue.record("No date was found, this should not happen in this test. (\(raw))")
            }
        }
    }

    @Test
    func testParsingAmbiguousDate() throws {

        // setup the raw string
        let rawStringMapping = ["20150203": dateFormatter.date(from: "2015-02-03"),
                                "02.03.2015": dateFormatter.date(from: "2015-03-02")]

        for (raw, date) in rawStringMapping {

            // calculate
            let parsedOutput = DateParser.parse(raw)

            // assert
            if let parsedDate = parsedOutput.first {
                let expectedDate = try #require(date)
                #expect(Calendar.current.isDate(parsedDate, inSameDayAs: expectedDate), "Found parsed output: \(parsedOutput)")
            } else {
                Issue.record("No date was found, this should not happen in this test.")
            }
        }
    }

    @Test
    func testParsingInvalidDates() {

        // setup the raw string
        let rawStrings = ["2015-35-12",
                          "122005023212",
                          "20050232",
                          "Berlin16072018666"]

        for raw in rawStrings {

            // calculate
            let parsedOutput = DateParser.parse(raw)

            // assert
            #expect(parsedOutput.isEmpty)
        }
    }

    @Test
    func testPerformanceExample() throws {

        // setup the long string
        let hiddenDate = "20050201"
        let longText = """
        Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.
        At vero eos et accusam et justo duo dolores et ea rebum.
        Stet clita kasd gubergren,\(hiddenDate)no sea takimata sanctus est Lorem ipsum dolor sit amet.
        Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.
        At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.
        """

        // measure the performance of the date parsing
        var parsedDate: Date?
//        self.measure {
        parsedDate = DateParser.parse(longText).first
//        }

        // assert
        if let parsedDate {
            let date = try #require(dateFormatter.date(from: "2005-02-01"))
            #expect(Calendar.current.isDate(parsedDate, inSameDayAs: date))
        } else {
            Issue.record("No date was found, this should not happen in this test.")
        }
    }
}
