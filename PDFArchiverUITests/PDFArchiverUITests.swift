//
//  PDFArchiverUITests.swift
//  PDFArchiverUITests
//
//  Created by Julian Kahnert on 29.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import XCTest

class PDFArchiverUITests: XCTestCase {
    var app: XCUIApplication?

    override func setUp() {
        super.setUp()
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = true

        // Fastlane snapshot Setup.
        app = XCUIApplication()
        if let app = app {
            setupSnapshot(app)
            app.launch()
        }
    }

    override func tearDown() {
        super.tearDown()
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        if let app = self.app {

            // take launch screenshot
            snapshot("01-Scan-Screen")

            let tabBarsQuery = app.tabBars
            tabBarsQuery.buttons["Archive"].tap()
            let cell = app.staticTexts["Tom Tailor Jeans"]
            let exists = NSPredicate(format: "exists == 1")
            expectation(for: exists, evaluatedWith: cell, handler: nil)
            waitForExpectations(timeout: 15, handler: nil)
            snapshot("03-Archive-Screen")

            tabBarsQuery.buttons["Tag"].tap()
            snapshot("02-Tag-Screen")
        }
    }

}
