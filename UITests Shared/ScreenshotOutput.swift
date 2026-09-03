//
//  ScreenshotOutput.swift
//  UITests
//
//  Created by Julian Kahnert on 03.09.26.
//

import ImageIO
import XCTest

/// The folder the App Store screenshots are written to, shared by both UI test targets.
enum ScreenshotOutput {

    /// The sidecar file is the fallback because a run from Xcode has no environment set, and
    /// measured, `xcodebuild` does not forward one into a simulator test runner either.
    static var directory: URL? {
        if let value = ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"] {
            return URL(fileURLWithPath: value)
        }
        let sidecar = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // UITests Shared
            .deletingLastPathComponent()   // the repository root
            .appendingPathComponent(".screenshot-output-dir")
        guard let value = try? String(contentsOf: sidecar, encoding: .utf8) else { return nil }
        return URL(fileURLWithPath: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Writes one capture and checks it arrived as a readable image - a run that silently writes
    /// nothing reports green otherwise, and the empty set is only noticed at the upload.
    static func write(_ screenshot: XCUIScreenshot,
                      named name: String,
                      file: StaticString = #filePath,
                      line: UInt = #line) throws {
        let outputDirectory = try XCTUnwrap(directory, file: file, line: line)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let url = outputDirectory.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: url)

        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), file: file, line: line)
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            file: file,
            line: line
        )
        XCTAssertGreaterThan(try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int), 0, file: file, line: line)
        XCTAssertGreaterThan(try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int), 0, file: file, line: line)
    }
}
