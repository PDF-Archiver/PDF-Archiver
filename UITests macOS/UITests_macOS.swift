//
//  UITests_macOS.swift
//  UITests macOS
//
//  Created by Julian Kahnert on 02.09.26.
//

import XCTest

/// Captures the macOS App Store screenshots by launching the app into a `ScreenshotCase`.
///
/// A UI test rather than a snapshot test because the window has to be real: on macOS 26 the
/// sidebar is a Liquid Glass container, and an offscreen `cacheDisplay` render neither draws it
/// nor traverses into it, leaving a blank white block where the sidebar belongs.
///
/// Only runs when a destination folder is configured.
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

    func testCaptureDocument() throws {
        try capture("03-document")
    }

    private func capture(_ screenshotCase: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotCase", screenshotCase]
        if let asset = ProcessInfo.processInfo.environment["SCREENSHOT_ASSET"] {
            app.launchArguments += ["-screenshotAsset", asset]
        }
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 60))

        try ScreenshotOutput.write(window.screenshot(), named: screenshotCase)
    }
}
