//
//  StoreScreenshots.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 02.09.26.
//

import CoreGraphics
import Foundation
import ImageIO
import SnapshotTesting
import Testing

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import SwiftUI
#endif

/// The pixel targets Apple requires, expressed as the point size and scale that produce them.
///
/// The library's own presets predate the 6.9" screen — `.iPhone13ProMax` renders 1284x2778,
/// which App Store Connect rejects for that bucket.
enum StoreSize {
    /// iPhone 6.9": 1320x2868 px = 440x956 pt @3x.
    static let iPhone69 = CGSize(width: 440, height: 956)
    /// iPad 13": 2064x2752 px = 1032x1376 pt @2x.
    static let iPad13 = CGSize(width: 1032, height: 1376)
    /// Mac: 2880x1800 px = 1440x900 pt @2x.
    static let mac = CGSize(width: 1440, height: 900)
}

#if os(iOS)
/// The trait collection that fixes the rendered pixel count. It comes from the *merged* traits;
/// the `scale:` argument on `.image` only affects reading a reference off disk.
@MainActor
func storeTraits(displayScale: CGFloat) -> UITraitCollection {
    UITraitCollection { $0.displayScale = displayScale }
}
#endif

#if os(macOS)
/// `NSView.cacheDisplay` takes its pixel count from the *window's* backing scale, so a hosted
/// view needs a window with a pinned one. Without it the render follows whatever display the
/// machine has — 2880x1800 on a Retina Mac, 1440x900 elsewhere, both valid upload sizes, which
/// is exactly why the drift goes unnoticed.
private final class ScaledWindow: NSWindow {
    private let pinnedScale: CGFloat

    init(scale: CGFloat, contentRect: CGRect) {
        pinnedScale = scale
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
    }

    override var backingScaleFactor: CGFloat { pinnedScale }
}

/// Hosts a SwiftUI view for capture. There is no `Snapshotting` for `SwiftUI.View` on macOS —
/// the library's file is `#if os(iOS) || os(tvOS)` — so the view goes through `NSHostingView`.
@MainActor
func macHostingView(_ view: some View, pointSize: CGSize = StoreSize.mac, scale: CGFloat = 2) -> NSView {
    let hosting = NSHostingView(rootView: view)
    hosting.frame = CGRect(origin: .zero, size: pointSize)
    let window = ScaledWindow(scale: scale, contentRect: hosting.frame)
    window.contentView = NSView(frame: hosting.frame)
    window.contentView?.addSubview(hosting)
    hosting.layoutSubtreeIfNeeded()
    return hosting
}
#endif

/// Where captures are written, or `nil` to behave like a plain snapshot test.
///
/// The sidecar file is not a style choice: `xcodebuild test` cannot inject environment variables
/// into a hostless test bundle on the simulator — neither `TEST_RUNNER_`- nor `SIMCTL_CHILD_`-
/// prefixed ones arrive. `swift test` on macOS does see the environment, hence both routes.
func screenshotOutputDirectory(relativeTo filePath: StaticString = #filePath) -> URL? {
    if let value = ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"] {
        return URL(filePath: value, directoryHint: .isDirectory)
    }
    guard let value = try? String(contentsOf: sidecarURL(relativeTo: filePath, named: ".screenshot-output-dir"),
                                  encoding: .utf8) else { return nil }
    return URL(filePath: value.trimmingCharacters(in: .whitespacesAndNewlines), directoryHint: .isDirectory)
}

/// The receipt PDF the tagging scenes show, which is deliberately not bundled with the app.
func screenshotAssetPath(relativeTo filePath: StaticString = #filePath) -> String? {
    if let value = ProcessInfo.processInfo.environment["SCREENSHOT_ASSET"] {
        return value
    }
    return try? String(contentsOf: sidecarURL(relativeTo: filePath, named: ".screenshot-asset"), encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func sidecarURL(relativeTo filePath: StaticString, named name: String) -> URL {
    URL(filePath: "\(filePath)")
        .deletingLastPathComponent()   // the test file's directory
        .deletingLastPathComponent()   // Tests/
        .deletingLastPathComponent()   // the package root
        .appending(component: name)
}

/// Writes one capture and returns the file it landed in.
///
/// Generation goes through `verifySnapshot` for two reasons: `assertSnapshot` has no
/// `snapshotDirectory:` parameter, and record mode *always* returns a failure message, even when
/// the reference matches. Dropping that message in generation mode is what keeps a capture run's
/// exit code at 0 while a real mismatch still fails the suite in test mode.
@discardableResult
@MainActor
func capture<Value, Format>(
    _ value: Value,
    as snapshotting: Snapshotting<Value, Format>,
    device: String,
    screen: String,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> URL {
    let output = screenshotOutputDirectory()
    let directory = output ?? defaultSnapshotDirectory(for: filePath)

    let message = verifySnapshot(
        of: value,
        as: snapshotting,
        named: screen,
        record: output == nil ? nil : .all,
        snapshotDirectory: directory.path(percentEncoded: false),
        fileID: fileID,
        file: filePath,
        testName: device,
        line: line,
        column: column
    )
    if output == nil, let message {
        Issue.record(Comment(rawValue: message),
                     sourceLocation: SourceLocation(fileID: "\(fileID)",
                                                    filePath: "\(filePath)",
                                                    line: Int(line),
                                                    column: Int(column)))
    }
    return directory
        .appending(component: "\(sanitizedComponent(device)).\(sanitizedComponent(screen))")
        .appendingPathExtension("png")
}

private func defaultSnapshotDirectory(for filePath: StaticString) -> URL {
    let file = URL(filePath: "\(filePath)")
    return file
        .deletingLastPathComponent()
        .appending(component: "__Snapshots__", directoryHint: .isDirectory)
        .appending(component: file.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
}

/// Mirrors the library's own path sanitising, so `capture` can name the file it wrote.
private func sanitizedComponent(_ component: String) -> String {
    component
        .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
        .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
}

/// Pixel dimensions straight from the PNG header, independent of any `scale` bookkeeping.
/// A wrong size is the one defect that survives all the way to the upload, so assert it.
func pixelSize(of url: URL, sourceLocation: SourceLocation = #_sourceLocation) throws -> CGSize {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), sourceLocation: sourceLocation)
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                                  sourceLocation: sourceLocation)
    let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int, sourceLocation: sourceLocation)
    let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int, sourceLocation: sourceLocation)
    return CGSize(width: width, height: height)
}
