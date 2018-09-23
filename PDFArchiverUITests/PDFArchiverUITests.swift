//
//  PDFArchiverUITests.swift
//  PDFArchiverUITests
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import XCTest

class PDFArchiverUITests: XCTestCase {

    override func setUp() {
        super.setUp()

        // assuming the following setup:
        // * german localization
        // * debug build
        // * internet connection available

        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test.
        // Doing this in setup will make sure it happens for each test method.
//        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation -
        // required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testDonationPrefs() {

        // Arrange
        let app = XCUIApplication()
        app.launch()

        let menuBarsQuery = app.menuBars
        menuBarsQuery.menuBarItems["PDFArchiver"].click()
        menuBarsQuery.menuItems["prefrencesMenu"].click()
        app.toolbars.buttons["Spenden"].click()

        // Act
        // wait until the products are loaded
        let exists = NSPredicate(format: "exists == false")
        expectation(for: exists, evaluatedWith: app.buttons["Level 1"], handler: nil)
        waitForExpectations(timeout: 5, handler: nil)

        // Assert
        XCTAssertNotEqual(app.buttons["level1"].title, "Level 1")
        XCTAssertNotEqual(app.buttons["level2"].title, "Level 2")
        XCTAssertNotEqual(app.buttons["level3"].title, "Level 3")
    }

}
