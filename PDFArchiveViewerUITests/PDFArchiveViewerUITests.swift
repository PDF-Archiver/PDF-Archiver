//
//  PDFArchiveViewerUITests.swift
//  PDFArchiveViewerUITests
//
//  Created by Julian Kahnert on 29.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import XCTest

class PDFArchiveViewerUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = true

        // Fastlane snapshot Setup.
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
       snapshot("01-LaunchScreen")
    }

}
