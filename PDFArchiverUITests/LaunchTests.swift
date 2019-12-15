//
//  LaunchTests.swift
//  PDFArchiverUITests
//
//  Created by Julian Kahnert on 06.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import XCTest

class LaunchTests: XCTestCase {
    func testLaunchPerformance() {
        measure(metrics: [XCTOSSignpostMetric.applicationLaunch]) {
            XCUIApplication().launch()
        }
    }
}
