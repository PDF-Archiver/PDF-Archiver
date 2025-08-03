//
//  TagParserTests.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 28.12.18.
//

import PDFKit
@testable import Shared
import Testing

@MainActor
struct TagParserTests {
    @Test
    func testParsingValidTags() async throws {

        // setup the raw string
        let rawStringMapping: [String: Set<String>] = [
            "This is a IKEA tradfri bulb!": Set(["ikea"]),
            "Bill of an Apple MacBook.": Set(["apple", "bill", "macbook"])
        ]

        for (raw, referenceTags) in rawStringMapping {

            // calculate
            let tags = TagParser.parse(raw)

            // assert
            #expect(tags == referenceTags)
        }
    }

    @Test
    func testParsingInvalidTags() {

        // setup the raw string
        let rawStringMapping: [String: Set<String>] = [
            "Die DKB ist eine Bank.": Set()
        ]

        for (raw, referenceTags) in rawStringMapping {

            // calculate
            let tags = TagParser.parse(raw)

            // assert
            #expect(tags == referenceTags)
        }
    }
}
