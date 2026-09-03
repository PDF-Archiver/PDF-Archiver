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
/// The size follows the simulator rather than a layout argument, so one run captures one device
/// family - which is also what picks the `iphone` or `ipad` output folder.
///
/// The numbers match the shot list in the marketing briefing, which is why they are not
/// contiguous: 03 to 07 cannot be produced from a simulator.
final class AppStoreScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        // The store takes the iPad shots in landscape, and a capture follows the device.
        XCUIDevice.shared.orientation = ScreenshotDevice.current == .ipad ? .landscapeLeft : .portrait
    }

    func testCaptureArchive() throws {
        try capture("01-archive")
    }

    func testCaptureTagging() throws {
        // A word off the receipt plus a tag suggestion: the page is rendered and the form is filled.
        try capture("02-tagging", readyWhenVisible: ["Barometer", "Tomtailor"])
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

    /// One launch per store locale: the language decides both the fixture language and the folder
    /// the shot is written to.
    ///
    /// `readyWhenVisible` lists what the finished shot has to show first - the tagging shot opens
    /// a document after the first render and fills its form asynchronously after that.
    private func capture(_ screenshotCase: String, readyWhenVisible texts: [String] = []) throws {
        let receipt = try ScreenshotReceipt.url()

        for locale in ScreenshotLocale.allCases {
            let app = XCUIApplication()
            app.launch(screenshotCase, locale: locale, receipt: receipt)

            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60))
            for text in texts {
                XCTAssertTrue(app.waitForVisibleText(text), "\(text) never appeared")
            }

            // The test runner is an app of its own, and the waits above hand focus back to it -
            // an unfocused window renders its title bar greyed out.
            app.activate()

            try ScreenshotOutput.write(XCUIScreen.main.screenshot(), named: screenshotCase, locale: locale)
            app.terminate()
        }
    }
}
