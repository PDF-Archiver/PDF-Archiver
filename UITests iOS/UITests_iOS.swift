//
//  UITests_iOS.swift
//  UITests iOS
//
//  Created by Julian Kahnert on 08.01.21.
//

import ImageIO
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
/// The destination comes from `SCREENSHOT_OUTPUT_DIR` or a `.screenshot-output-dir` sidecar, and
/// holds one device family — point it at `iphone/` for an iPhone 6.9" destination and `ipad/` for
/// an iPad 13" one, because the size follows the simulator rather than a layout argument.
///
/// The numbers match the shot list in the marketing briefing, which is why they are not
/// contiguous: 03, 04, 06 and 07 cannot be produced from a simulator. The 2x numbers are press
/// kit shots, which the store series does not use.
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
        if let asset = ProcessInfo.processInfo.environment["SCREENSHOT_ASSET"] {
            app.launchArguments += ["-screenshotAsset", asset]
        }
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60))
        // Any text proves the scene finished building, whatever the language or screen.
        XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 60))

        let directory = try XCTUnwrap(Self.outputDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: file)

        // A capture run that writes nothing still reports green otherwise, and the empty set is
        // only noticed at the upload.
        let size = try pixelSize(of: file)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
    }

    private func pixelSize(of url: URL) throws -> (width: Int, height: Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int),
                try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int))
    }

    /// The sidecar file is the fallback because a run from Xcode has no environment set, and
    /// measured, `xcodebuild` does not forward one into a simulator test runner either.
    private static var outputDirectory: URL? {
        if let value = ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"] {
            return URL(fileURLWithPath: value)
        }
        let sidecar = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // UITests iOS
            .deletingLastPathComponent()   // the repository root
            .appendingPathComponent(".screenshot-output-dir")
        guard let value = try? String(contentsOf: sidecar, encoding: .utf8) else { return nil }
        return URL(fileURLWithPath: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
