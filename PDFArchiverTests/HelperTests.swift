//
//  HelperTests.swift
//  PDF ArchiverTests
//
//  Created by Julian Kahnert on 03.06.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

@testable import PDFArchiver
import XCTest

class HelperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSlugifySpecialCharacters() {
        // capital letters
        XCTAssertEqual("Ä".slugify(), "Ae")
        XCTAssertEqual("Ö".slugify(), "Oe")
        XCTAssertEqual("Ü".slugify(), "Ue")
        // small letters
        XCTAssertEqual("ä".slugify(), "ae")
        XCTAssertEqual("ö".slugify(), "oe")
        XCTAssertEqual("ü".slugify(), "ue")
        // other
        XCTAssertEqual("ß".slugify(), "ss")
    }

    func testSlugifyName1() {
        let exampleString = "Das hier ist-ein__öffentlicher TÄst!"

        XCTAssertEqual(exampleString.lowercased().slugify(), "das-hier-ist-ein-oeffentlicher-taest")
        XCTAssertNotEqual(exampleString.lowercased().slugify(), exampleString)
    }

    func testSlugifyName2() {
        let exampleString = " Das hier ist ein Test "

        XCTAssertEqual(exampleString.lowercased().slugify(), "das-hier-ist-ein-test")
        XCTAssertNotEqual(exampleString.lowercased().slugify(), exampleString)
    }

}
