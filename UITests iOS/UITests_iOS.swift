//
//  UITests_iOS.swift
//  UITests iOS
//
//  Created by Julian Kahnert on 08.01.21.
//

import XCTest

#warning("TODO: add these tests again")
final class UITestsiOS: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = XCUIApplication()
        app.launchArguments.append("-tutorial-v1")
        app.launchArguments.append("true")
        setupSnapshot(app, waitForAnimations: true)
        app.launch()
    }

//    func testSelectScan() throws {
//        let tabBar = app.tabBars.firstMatch
//        _ = tabBar.waitForExistence(timeout: 10)
//        tabBar.buttons[NSLocalizedString("Scan", comment: "")].tap()
//        snapshot("01-Scan-Screen")
//    }
//
//    func testSelectTag() throws {
//        let tabBar = app.tabBars.firstMatch
//        _ = tabBar.waitForExistence(timeout: 10)
//        tabBar.buttons[NSLocalizedString("Tag", comment: "")].tap()
//        snapshot("02-Tag-Screen")
//    }
//
//    func testSelectArchive() throws {
//        let tabBar = app.tabBars.firstMatch
//        _ = tabBar.waitForExistence(timeout: 10)
//        tabBar.buttons[NSLocalizedString("Archive", comment: "")].tap()
//        snapshot("03-Archive-Screen")
//    }
//
//    func testSelectMore() throws {
//        let tabBar = app.tabBars.firstMatch
//        _ = tabBar.waitForExistence(timeout: 10)
//        tabBar.buttons[NSLocalizedString("More", comment: "")].tap()
//        snapshot("04-More-Screen")
//    }
}

/// Captures the raw App Store screenshots by launching the app into a `ScreenshotCase`.
///
/// The destination holds one device family - point it at `iphone/` for an iPhone 6.9" simulator
/// and `ipad/` for an iPad 13" one, because the size follows the simulator rather than a layout
/// argument.
///
/// The numbers match the shot list in the marketing briefing, which is why they are not
/// contiguous: 03 to 07 cannot be produced from a simulator. The 2x numbers are press kit shots,
/// which the store series does not use.
final class AppStoreScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        try XCTSkipIf(ScreenshotOutput.directory == nil, "SCREENSHOT_OUTPUT_DIR is not set")
    }

    func testCaptureArchive() throws {
        try capture("01-archive")
    }

    func testCaptureTagging() throws {
        try capture("02-tagging")
    }

    func testCaptureTrial() throws {
        try capture("08-trial")
    }

    func testCaptureInbox() throws {
        try capture("20-inbox")
    }

    func testCaptureStatistics() throws {
        try capture("21-statistics")
    }

    private func capture(_ screenshotCase: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotCase", screenshotCase]
        if let asset = ProcessInfo.processInfo.environment["SCREENSHOT_ASSET"] {
            app.launchArguments += ["-screenshotAsset", asset]
        }
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60))

        try ScreenshotOutput.write(XCUIScreen.main.screenshot(), named: screenshotCase)
    }
}
