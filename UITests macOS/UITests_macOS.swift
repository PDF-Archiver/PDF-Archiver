//
//  UITests_macOS.swift
//  UITests macOS
//
//  Created by Julian Kahnert on 02.09.26.
//

import XCTest

/// Captures the macOS App Store screenshots by launching the app into a `ScreenshotScene`.
///
/// A UI test rather than a snapshot test because the window has to be real: on macOS 26 the
/// sidebar is a Liquid Glass container, and an offscreen `cacheDisplay` render neither draws it
/// nor traverses into it, leaving a blank white block where the sidebar belongs.
///
/// Only runs when `SCREENSHOT_OUTPUT_DIR` names a destination folder.
final class AppStoreScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        try XCTSkipIf(Self.outputDirectory == nil, "SCREENSHOT_OUTPUT_DIR is not set")
    }

    func testCaptureArchive() throws {
        try capture(scene: "mac", named: "01-archive")
    }

    func testCaptureTagging() throws {
        try capture(scene: "macTagging", named: "02-tagging")
    }

    func testCaptureDocument() throws {
        try capture(scene: "macDocument", named: "03-document")
    }

    private func capture(scene: String, named name: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotScene", scene]
        if let asset = ProcessInfo.processInfo.environment["SCREENSHOT_ASSET"] {
            app.launchArguments += ["-screenshotAsset", asset]
        }
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 60))
        // Any text proves the scene finished building, whatever the language or screen.
        XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 60))

        let directory = try XCTUnwrap(Self.outputDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("\(name).png")
        try window.screenshot().pngRepresentation.write(to: file)

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
    /// measured on iOS `xcodebuild` does not forward one into a test runner either.
    private static var outputDirectory: URL? {
        if let value = ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"] {
            return URL(fileURLWithPath: value)
        }
        let sidecar = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // UITests macOS
            .deletingLastPathComponent()   // the repository root
            .appendingPathComponent(".screenshot-output-dir")
        guard let value = try? String(contentsOf: sidecar, encoding: .utf8) else { return nil }
        return URL(fileURLWithPath: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
