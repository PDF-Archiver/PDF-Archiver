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

    @Test(arguments: [
        ("Ä", "Ae"),
        ("Ö", "Oe"),
        ("Ü", "Ue"),
        ("ä", "ae"),
        ("ö", "oe"),
        ("ü", "ue"),
        ("ß", "ss"),
        ("é", "e"),
        ("2017", "2017"),
        ("AbC2017", "AbC2017"),
        ("AbC, 2017 Def", "AbC-2017-Def"),
        ("привет", ""),
        ("Liebe Grüße aus Ovelgönne", "Liebe-Gruesse-aus-Ovelgoenne"),
        ("Hello, ___ this !! is a TEst!?!", "Hello-this-is-a-TEst"),
        ("Hello ---- again!!", "Hello-again"),
    ])
    func slugify(input: String, expected: String) {
        #expect(input.slugified() == expected)
    }

    @Test
    func capitalizingFirstLetter() {

        // setup
        let testString = "test"

        // calculate
        let output = testString.capitalized

        // assert
        #expect(output == "Test")
    }

    @Test
    func capitalizingFirstLetterMultipleWords() {

        // setup
        let testString = "this is another test"

        // calculate
        let output = testString.capitalized

        // assert
        #expect(output == "This Is Another Test")
    }

    @Test
    func replacingMethod() {

        // setup
        let testString = "Äpfel und Öl"

        // calculate
        let output = testString.replacing("Ä", with: "Ae")
                                .replacing("Ö", with: "Oe")

        // assert
        #expect(output == "Aepfel und Oel")
    }

    @Test
    func replacingWithRegex() {

        // setup
        let testString = "test--multiple---dashes"

        // calculate
        let output = testString.replacing(/[^0-9a-zA-Z]+/, with: "-")

        // assert
        #expect(output == "test-multiple-dashes")
    }

    @Test
    func replacingSpecialCharacters() {

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
