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

        document.click()
        try write(named: "02-document")

        let edit = app.buttons["Bearbeiten"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 30), "edit button missing:\n\(app.windows.firstMatch.debugDescription)")
        edit.click()

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
            next.click()
            sleep(1)
        }

        // The last page swaps the arrow for a confirm button.
        let done = app.buttons["checkmark.circle.fill"].firstMatch
        if done.waitForExistence(timeout: 5) {
            done.click()
        }
        sleep(3)
    }

    /// Writes the screenshot to disk so the images can be reviewed outside of the result bundle.
    ///
    /// The runner is sandboxed and cannot write into the checkout, so it falls back to its own
    /// temporary directory and prints where the file ended up.
    private func write(named name: String) throws {
        sleep(2)
        // Scoped to the window on purpose: XCUIScreen captures the whole desktop, which would put
        // whatever else is open on screen into the reference images.
        let screenshot = app.windows.firstMatch.screenshot()
        add(XCTAttachment(screenshot: screenshot))

        let filename = "macos-\(name).png"
        let checkout = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".screenshots")

        for directory in [checkout, FileManager.default.temporaryDirectory] {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let destination = directory.appendingPathComponent(filename)
                try screenshot.pngRepresentation.write(to: destination)
                print("SCREENSHOT \(destination.path)")
                return
            } catch {
                continue
            }
        }

        XCTFail("could not write \(filename) anywhere")
    }
}
