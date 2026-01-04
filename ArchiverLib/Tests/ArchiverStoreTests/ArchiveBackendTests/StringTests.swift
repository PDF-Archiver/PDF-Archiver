//
//  StringTests.swift
//  
//
//  Created by Julian Kahnert on 29.11.20.
//

import Shared
import Testing

@MainActor
struct StringExtensionTests {

    @Test
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
            #expect(newSlugifiedString == slugified)
        }
    }

    @Test
    func testCapitalizingFirstLetter() {

        // setup
        let testString = "test"

        // calculate
        let output = testString.capitalized

        // assert
        #expect(output == "Test")
    }

    @Test
    func testCapitalizingFirstLetter2() {

        // setup
        let testString = "this is another test"

        // calculate
        let output = testString.capitalized

        // assert
        #expect(output == "This Is Another Test")
    }

    @Test
    func testReplacingMethod() {

        // setup
        let testString = "Äpfel und Öl"

        // calculate
        let output = testString.replacing("Ä", with: "Ae")
                                .replacing("Ö", with: "Oe")

        // assert
        #expect(output == "Aepfel und Oel")
    }

    @Test
    func testReplacingWithRegex() {

        // setup
        let testString = "test--multiple---dashes"

        // calculate
        let output = testString.replacing(/[^0-9a-zA-Z]+/, with: "-")

        // assert
        #expect(output == "test-multiple-dashes")
    }

    @Test
    func testReplacingSpecialCharacters() {

        // setup
        let testString = "ß test ä ö ü Ä Ö Ü"

        // calculate
        let output = testString.replacing("ß", with: "ss")
                                .replacing("ä", with: "ae")
                                .replacing("ö", with: "oe")
                                .replacing("ü", with: "ue")
                                .replacing("Ä", with: "Ae")
                                .replacing("Ö", with: "Oe")
                                .replacing("Ü", with: "Ue")

        // assert
        #expect(output == "ss test ae oe ue Ae Oe Ue")
    }
}
