//
//  TagParserTests.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 28.12.18.
//

import ArchiveBackend
import PDFKit
import XCTest

final class TagParserTests: XCTestCase {

    func testParsingValidTags() {

        // setup the raw string
        let rawStringMapping: [String: Set<String>] = [
            "This is a IKEA tradfri bulb!": Set(["ikea"]),
            "Bill of an Apple MacBook.": Set(["apple", "bill", "macbook"])
        ]

        for (raw, referenceTags) in rawStringMapping {

            // calculate
            let tags = TagParser.parse(raw)

            // assert
            if #available(iOS 12.0, OSX 10.14, *) {
                XCTAssertEqual(tags, referenceTags)
            } else {
                XCTAssertEqual(tags, Set())
            }
        }
    }

    func testParsingInvalidTags() {

        // setup the raw string
        let rawStringMapping: [String: Set<String>] = [
            "Die DKB ist eine Bank.": Set()
        ]

        for (raw, referenceTags) in rawStringMapping {

            // calculate
            let tags = TagParser.parse(raw)

            // assert
            XCTAssertEqual(tags, referenceTags)
        }
    }

    func testPerformanceExample() throws {
        let examplePdfUrl = Bundle.longTextPDFUrl
        let document = try XCTUnwrap(PDFDocument(url: examplePdfUrl))

        var content = ""
        for pageNumber in 0..<min(document.pageCount, 10) {
            content += document.page(at: pageNumber)?.string ?? ""
        }

        // measure the performance of the date parsing
        var tags: Set<String>?
        self.measure {
            tags = TagParser.parse(content)
        }

        let foundTags = try XCTUnwrap(tags)
        XCTAssert(foundTags.contains("versicherungsschutz"))
        XCTAssert(foundTags.contains("produkt"))
        XCTAssert(foundTags.contains("bank"))
    }
}
