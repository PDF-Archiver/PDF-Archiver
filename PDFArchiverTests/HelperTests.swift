//
//  HelperTests.swift
//  PDF ArchiverTests
//
//  Created by Julian Kahnert on 03.06.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import XCTest
@testable import PDF_Archiver

class HelperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSlugify() {
        // capital letters
        XCTAssertEqual(slugify("Ä"), "ae")
        XCTAssertEqual(slugify("Ö"), "oe")
        XCTAssertEqual(slugify("Ü"), "ue")
        // small letters
        XCTAssertEqual(slugify("ä"), "ae")
        XCTAssertEqual(slugify("ö"), "oe")
        XCTAssertEqual(slugify("ü"), "ue")
        // other
        XCTAssertEqual(slugify("ß"), "ss")
    }

}
