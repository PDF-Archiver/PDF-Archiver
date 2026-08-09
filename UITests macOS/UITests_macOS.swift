//
//  UITests_macOS.swift
//  UITests macOS
//

import XCTest

final class UITestsmacOS: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        app = XCUIApplication()
        // `shared-` prefixed keys are what the Sharing app storage actually reads; the bare
        // `tutorial-v1` is only consulted as a legacy fallback. Values go through property list
        // parsing, so `1` arrives as a number that casts to Bool - `true` would stay a string.
        app.launchArguments.append(contentsOf: [
            "-demoMode", "1",
            "-shared-tutorial-v1", "1",
            "-tutorial-v1", "1"
        ])
        app.launch()
    }

    /// Captures the document information form as it is really presented on macOS: an inspector
    /// column next to the document, opened from the document toolbar.
    func testDocumentInspector() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60))
        dismissTutorial()

        let document = app.outlines.cells.firstMatch.exists
            ? app.outlines.cells.firstMatch
            : app.collectionViews.cells.firstMatch
        XCTAssertTrue(document.waitForExistence(timeout: 60), "no document in the archive:\n\(app.windows.firstMatch.debugDescription)")
        try write(named: "01-archive")

        document.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        try write(named: "02-document")

        let edit = app.buttons["Bearbeiten"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 30), "edit button missing:\n\(app.windows.firstMatch.debugDescription)")
        edit.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()

        sleep(3)
        try write(named: "03-document-with-inspector")
    }

    // MARK: - Helper

    /// The tutorial sheet slides in a moment after launch and ignores the app storage launch
    /// argument, so it gets clicked through instead.
    private func dismissTutorial() {
        let next = app.buttons["arrow.right.circle.fill"].firstMatch
        guard next.waitForExistence(timeout: 20) else { return }

        for _ in 0..<8 where next.exists {
            next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            sleep(1)
        }

        // The last page swaps the arrow for a confirm button.
        let done = app.buttons["checkmark.circle.fill"].firstMatch
        if done.waitForExistence(timeout: 5) {
            done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
        sleep(3)
    }

    /// Writes the screenshot next to the test sources on the host, so the images can be reviewed
    /// outside of the result bundle.
    private func write(named name: String) throws {
        sleep(2)
        let screenshot = XCUIScreen.main.screenshot()
        add(XCTAttachment(screenshot: screenshot))

        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".screenshots")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("macos-\(name).png"))
    }
}
