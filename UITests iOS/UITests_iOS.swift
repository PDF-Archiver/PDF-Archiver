//
//  UITests_iOS.swift
//  UITests iOS
//
//  Created by Julian Kahnert on 08.01.21.
//

import XCTest

class UITestsiOS: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = XCUIApplication()
        app.launchArguments.append("-demoMode")
        app.launchArguments.append("true")
        app.launchArguments.append("-tutorial-v1")
        app.launchArguments.append("true")
        setupSnapshot(app, waitForAnimations: true)
        app.launch()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSelectScan() throws {
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)
        tabBar.buttons[NSLocalizedString("Scan", comment: "")].tap()
        snapshot("01-Scan-Screen")
    }

    func testSelectTag() throws {
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)
        tabBar.buttons[NSLocalizedString("Tag", comment: "")].tap()
        snapshot("02-Tag-Screen")
    }

    func testSelectArchive() throws {
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)
        tabBar.buttons[NSLocalizedString("Archive", comment: "")].tap()
        snapshot("03-Archive-Screen")
    }

    func testSelectMore() throws {
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)
        tabBar.buttons[NSLocalizedString("More", comment: "")].tap()
        snapshot("04-More-Screen")
    }
}
