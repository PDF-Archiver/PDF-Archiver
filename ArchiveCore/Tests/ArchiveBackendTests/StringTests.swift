//
//  StringTests.swift
//  
//
//  Created by Julian Kahnert on 29.11.20.
//

import ArchiveBackend
import XCTest

final class StringExtensionTests: XCTestCase {

    func testSlugify() {

        // setup
        let stringMapping = ["Ä": "Ae",
                             "Ö": "Oe",
                             "Ü": "Ue",
                             "ä": "ae",
                             "ö": "oe",
                             "ü": "ue",
                             "ß": "ss",
                             "é": "e",
                             "2017": "2017",
                             "AbC2017": "AbC2017",
                             "AbC, 2017 Def": "AbC-2017-Def",
                             "привет": "",
                             "Liebe Grüße aus Ovelgönne": "Liebe-Gruesse-aus-Ovelgoenne",
                             "Hello, ___ this !! is a TEst!?!": "Hello-this-is-a-TEst",
                             "Hello ---- again!!": "Hello-again"]

        for (raw, slugified) in stringMapping {

            // calculate
            let newSlugifiedString = raw.slugified()

            // assert
            XCTAssertEqual(newSlugifiedString, slugified)
        }
    }

    func testCapturedGroups() throws {

        // setup
        let testString = "2010-05-12--example-description__tag1_tag2_tag3"

        // calculate
        let regex = try NSRegularExpression(pattern: "__([\\w\\d_]+)", options: [])
        let groups = testString.capturedGroups(withRegex: regex)

        // assert
        if let groups = groups {
            XCTAssertEqual(groups[0], "tag1_tag2_tag3")
        } else {
            XCTFail("No group found. This should not happen.")
        }
    }

    func testCapturedGroupsInvalid() throws {

        // setup
        let testString = "2010-05-12--example-description"

        // calculate
        // no groups in test string
        let regex = try NSRegularExpression(pattern: "__([\\w\\d_]+)", options: [])
        let groups1 = testString.capturedGroups(withRegex: regex)
        // invalid regular expression
        XCTAssertThrowsError(try NSRegularExpression(pattern: "([", options: []))

        // assert
        XCTAssertNil(groups1)
    }

    func testCapitalizingFirstLetter() {

        // setup
        let testString = "test"

        // calculate
        let output = testString.capitalized

        // assert
        XCTAssertEqual(output, "Test")
    }

    func testCapitalizingFirstLetter2() {

        // setup
        let testString = "this is another test"

        // calculate
        let output = testString.capitalized

        // assert
        XCTAssertEqual(output, "This Is Another Test")
    }

    func testCapturedGroupsPerformance() throws {

        // setup
        let testString = "2010-05-12--example-description__tag1_tag2_tag3"

        // calculate
        let regex = try NSRegularExpression(pattern: "__([\\w\\d_]+)", options: [])
        var groups: [String]?
        measure {
            groups = testString.capturedGroups(withRegex: regex)
        }

        // assert
        if let groups = groups {
            XCTAssertEqual(groups[0], "tag1_tag2_tag3")
        } else {
            XCTFail("No group found. This should not happen.")
        }
    }
}
