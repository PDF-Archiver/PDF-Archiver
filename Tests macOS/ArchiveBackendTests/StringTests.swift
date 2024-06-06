//
//  StringTests.swift
//  
//
//  Created by Julian Kahnert on 29.11.20.
//

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
}
