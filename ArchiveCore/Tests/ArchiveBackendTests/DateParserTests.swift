//
//  DateParser.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 30.11.18.
//
// swiftlint:disable function_body_length force_unwrapping

import ArchiveBackend
import PDFKit
import XCTest

final class DateParserTests: XCTestCase {

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    func testParsingValidDate() throws {

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
            "n16072018n": dateFormatter.date(from: "2018-07-16"),
            "Berlin16072018test": dateFormatter.date(from: "2018-07-16"),
            "Berlin16072018": dateFormatter.date(from: "2018-07-16"),
            "1.05.2015": dateFormatter.date(from: "2015-05-01"),
            "12.05.2015": dateFormatter.date(from: "2015-05-12"),
            "12-05-2015": dateFormatter.date(from: "2015-05-12"),
            "2015-05-12": dateFormatter.date(from: "2015-05-12"),
            "2015-13-12": dateFormatter.date(from: "2015-12-13"),
            "1990_02_11": dateFormatter.date(from: "1990-02-11"),
            "20050301": dateFormatter.date(from: "2005-03-01"),
            "2010_05_12_15_17": dateFormatter.date(from: "2010-05-12"),
            "09/10/2018": dateFormatter.date(from: "2018-10-09"),
            "nn09/10/2018nn": dateFormatter.date(from: "2018-10-09"),
            "199002_11": dateFormatter.date(from: "1990-02-11"),
            "12.05-2020": dateFormatter.date(from: "2020-05-12"),
            "12. Januar 2020": dateFormatter.date(from: "2020-01-12"),
            "2. Jan 2020": dateFormatter.date(from: "2020-01-02"),
            "23. Feb. 2020": dateFormatter.date(from: "2020-02-23"),
            "23. February 2020": dateFormatter.date(from: "2020-02-23"),
            "19. february 2020": dateFormatter.date(from: "2020-02-19"),
            "6. dec 2020": dateFormatter.date(from: "2020-12-06"),
            "24. December 2020": dateFormatter.date(from: "2020-12-24"),
            "December 25, 2020": dateFormatter.date(from: "2020-12-25"),
            "05 01 18": dateFormatter.date(from: "2018-01-05"),
            longText: dateFormatter.date(from: "2005-02-01")
        ]

        for (raw, date) in rawStringMapping {

            // calculate
            let parsedOutput = DateParser.parse(raw)

            // assert
            if let parsedOutput = parsedOutput {
                XCTAssertTrue(Calendar.current.isDate(parsedOutput.date, inSameDayAs: try XCTUnwrap(date)))
            } else {
                XCTFail("No date was found, this should not happen in this test.")
            }
        }
    }

    func testParsingAmbiguousDate() throws {

        // setup the raw string
        let rawStringMapping = ["20150203": dateFormatter.date(from: "2015-02-03"),
                                "02.03.2015": dateFormatter.date(from: "2015-03-02")]

        for (raw, date) in rawStringMapping {

            // calculate
            let parsedOutput = DateParser.parse(raw)

            // assert
            if let parsedOutput = parsedOutput {
                XCTAssertTrue(Calendar.current.isDate(parsedOutput.date, inSameDayAs:  try XCTUnwrap(date)))
            } else {
                XCTFail("No date was found, this should not happen in this test.")
            }
        }
    }

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
            XCTAssertNil(parsedOutput)
        }
    }

    func testValidParsingLocale() throws {

        // setup the raw string
        let rawStringMapping = [
            "12. Dez. 2018": dateFormatter.date(from: "2018-12-12"),
            "2. Juli 2018": dateFormatter.date(from: "2018-07-02"),
            "1. Juni 2018": dateFormatter.date(from: "2018-06-01"),
            "12. Dezember 2018": dateFormatter.date(from: "2018-12-12"),
            "5. Februar 2018": dateFormatter.date(from: "2018-02-05")
        ]

        for (raw, date) in rawStringMapping {

            // calculate
            let parsedOutput = DateParser.parse(raw, locales: [Locale(identifier: "de_DE")])

            // assert
            let parsedDate = try XCTUnwrap(parsedOutput?.date)
            XCTAssertTrue(Calendar.current.isDate(parsedDate, inSameDayAs: try XCTUnwrap(date)))
        }
    }

    func testWrongLocale() throws {

        // setup the raw string
        let rawStrings = [
            "2. Dez. 2018": dateFormatter.date(from: "2018-12-2"),
            "12. Dezember 2018": dateFormatter.date(from: "2018-12-12"),
            "5. Februar 2018": dateFormatter.date(from: "2018-02-05")
        ]

        for (raw, date) in rawStrings {

            // calculate
            // test parsing with wrong locale => using NSDataDetector as a fallback
            let parsedOutput = DateParser.parse(raw, locales: [Locale(identifier: "en_US")])

            // assert
            let foundDate = try XCTUnwrap(parsedOutput?.date)
            XCTAssertTrue(Calendar.current.isDate(foundDate, inSameDayAs: date!))
        }
    }

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
        var parsedOutput: (date: Date, rawDate: String)?
        self.measure {
            parsedOutput = DateParser.parse(longText)
        }

        // assert
        if let parsedOutput = parsedOutput {
            let date = try XCTUnwrap(dateFormatter.date(from: "2005-02-01"))
            XCTAssertTrue(Calendar.current.isDate(parsedOutput.date, inSameDayAs: date))
        } else {
            XCTFail("No date was found, this should not happen in this test.")
        }
    }
    
    func testPerformanceExample2() throws {
        let examplePdfUrl = Bundle.longTextPDFUrl
        let document = try XCTUnwrap(PDFDocument(url: examplePdfUrl))
        
        var content = ""
        for pageNumber in 0..<min(document.pageCount, 1) {
            content += document.page(at: pageNumber)?.string ?? ""
        }
        
        // measure the performance of the date parsing
        var parsedOutput: (date: Date, rawDate: String)?
        self.measure {
            parsedOutput = DateParser.parse(content)
        }
     
        XCTAssertNil(parsedOutput)
    }
}
