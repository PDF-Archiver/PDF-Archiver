//
//  PDFArchiveViewerUITests.swift
//  PDFArchiveViewerUITests
//
//  Created by Julian Kahnert on 29.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import XCTest

class PDFArchiveViewerUITests: XCTestCase {
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
            let cell = app.staticTexts["Tom Tailor Jeans"]
            let exists = NSPredicate(format: "exists == 1")

            expectation(for: exists, evaluatedWith: cell, handler: nil)
            waitForExpectations(timeout: 15, handler: nil)

            // take launch screenshot
            snapshot("01-Launch-Screen")

            // tap on the label
            cell.tap()

            // take pdf screenshot
            snapshot("02-PDF-Screen")
        }
    }

}
