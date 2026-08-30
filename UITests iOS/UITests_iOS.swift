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

/// Captures the raw App Store screenshots by launching the app straight into a `ScreenshotScene`.
///
/// Only runs when `SCREENSHOT_OUTPUT_DIR` names a destination folder, so a normal UI test run is
/// unaffected. The numbers match the shot list in the marketing briefing, which is why they are
/// not contiguous: 03, 04, 06 and 07 cannot be produced from a simulator. The 2x numbers are
/// press kit shots, which the store series does not use.
final class AppStoreScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        try XCTSkipIf(Self.outputDirectory == nil, "SCREENSHOT_OUTPUT_DIR is not set")
    }

    func testCaptureArchive() throws {
        try capture(scene: "archive", named: "01-archive")
    }

    func testCaptureTagging() throws {
        try capture(scene: "tagging", named: "02-tagging")
    }

    func testCaptureStorage() throws {
        try capture(scene: "storage", named: "05-on-device")
    }

    func testCaptureTrial() throws {
        try capture(scene: "trial", named: "08-trial")
    }

    func testCaptureInbox() throws {
        try capture(scene: "inbox", named: "20-inbox")
    }

    func testCaptureStatistics() throws {
        try capture(scene: "statistics", named: "21-statistics")
    }

    private func capture(scene: String, named name: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotScene", scene]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60))
        // Any text proves the scene finished building, whatever the language or screen.
        XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 60))

        let directory = try XCTUnwrap(Self.outputDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot()
            .pngRepresentation
            .write(to: directory.appendingPathComponent("\(name).png"))
    }

    private static var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"].map { URL(fileURLWithPath: $0) }
    }
}
