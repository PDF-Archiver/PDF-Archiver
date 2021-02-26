//
//  Tests_macOS.swift
//  Tests macOS
//
//  Created by Julian Kahnert on 24.06.20.
//

import XCTest

// swiftlint:disable:next type_name
final class Tests_macOS: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

//    @available(OSX 11.0, *)
//    func testLaunchPerformance() throws {
//        // This measures how long it takes to launch your application.
//        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
//            XCUIApplication().launch()
//        }
//    }
}
