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
/// The three shots tell one story: the receipt sits in the inbox, gets its tags, and is found in
/// the archive under them.
final class AppStoreScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testCaptureArchive() throws {
        // The filed receipt is one of the search hits - that is the end of the flow.
        try capture("01-archive", readyWhenVisible: ["tom-tailor-jeans"])
    }

    func testCaptureTagging() throws {
        // A word off the receipt plus a tag suggestion: the page is rendered and the form is filled.
        try capture("02-tagging", readyWhenVisible: ["Barometer", "Tomtailor"])
    }

    func testCaptureDocument() throws {
        try capture("03-document", readyWhenVisible: ["Barometer"])
    }

    /// One launch per store locale: the language decides both the fixture language and the folder
    /// the shot is written to.
    ///
    /// `readyWhenVisible` lists what the finished shot has to show first - the cases that open a
    /// document do so after the first render, and fill the form asynchronously after that.
    private func capture(_ screenshotCase: String, readyWhenVisible texts: [String] = []) throws {
        let receipt = try ScreenshotReceipt.url()

        for locale in ScreenshotLocale.allCases {
            let app = XCUIApplication()
            app.launch(screenshotCase, locale: locale, receipt: receipt)

            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 60))
            for text in texts {
                XCTAssertTrue(app.waitForVisibleText(text), "\(text) never appeared")
            }

            // The test runner is an app of its own, and the waits above hand focus back to it -
            // an unfocused window renders its title bar greyed out.
            app.activate()

            try ScreenshotOutput.write(window.screenshot(), named: screenshotCase, locale: locale)
            app.terminate()
        }
    }
}
