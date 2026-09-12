//
//  ScreenshotOutput.swift
//  UITests
//
//  Created by Julian Kahnert on 03.09.26.
//

import ImageIO
import UniformTypeIdentifiers
import XCTest
#if canImport(UIKit)
import UIKit
#endif

/// The store locales the screenshots are produced for: one app launch each, one output folder each.
enum ScreenshotLocale: String, CaseIterable {
    case german = "de-DE"
    case english = "en-US"

    /// The app reads its language from the argument domain, so `-AppleLanguages` has to arrive as
    /// a plist array literal.
    var launchArguments: [String] {
        ["-AppleLanguages", "(\(languageCode))",
         "-AppleLocale", rawValue.replacingOccurrences(of: "-", with: "_")]
    }

    private var languageCode: String {
        Locale(identifier: rawValue).language.languageCode?.identifier ?? rawValue
    }
}

/// The device families the store asks for, each with the pixel sizes it accepts.
enum ScreenshotDevice: String {
    case mac
    case iphone
    case ipad

    /// The run destination decides this - the Mac app, an iPhone Air or an iPad Pro simulator.
    static var current: ScreenshotDevice {
        #if os(macOS)
        return .mac
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
    }

    /// The one size per family this app is uploaded in, out of the
    /// [App Store Connect specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
    /// A capture is never resampled, so a run has to produce exactly this by itself:
    /// - `mac`: the pinned 720 x 450 point window on a Retina display - the smaller window is
    ///   what makes the app's text readable at store size
    /// - `iphone`: iPhone Air, portrait
    /// - `ipad`: iPad Pro 13" (M5), landscape
    var storeSize: CGSize {
        switch self {
        case .mac:
            return CGSize(width: 1440, height: 900)

        case .iphone:
            return CGSize(width: 1260, height: 2736)

        case .ipad:
            return CGSize(width: 2752, height: 2064)
        }
    }
}

/// The TOM TAILOR till receipt the tagging and document shots show.
enum ScreenshotReceipt {

    /// Checked in as a test asset and deliberately not bundled, so the shop's address and VAT
    /// number stay out of the shipped app.
    private static let source = ScreenshotOutput.repositoryRoot
        .appendingPathComponent("ArchiverLib/Tests/DocumentProcessingPipelineTests/assets/document1.pdf")

    /// The path handed to the app as `-screenshotAsset`.
    ///
    /// The Mac app is sandboxed and can read nothing but its own container, so the receipt is
    /// copied in there; the simulator app reads the repository path directly.
    static func url() throws -> URL {
        #if os(macOS)
        // The runner is sandboxed as well, so its home is `<home>/Library/Containers/<id>/Data`
        // and the app's container sits next to it.
        let appTemporaryDirectory = URL(fileURLWithPath: NSHomeDirectory())
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(components: appBundleIdentifier, "Data", "tmp")
        try FileManager.default.createDirectory(at: appTemporaryDirectory, withIntermediateDirectories: true)

        let destination = appTemporaryDirectory.appending(component: source.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
        #else
        return source
        #endif
    }

    #if os(macOS)
    private static let appBundleIdentifier = "de.JulianKahnert.PDFArchiveViewer"
    #endif
}

extension XCUIApplication {

    /// Launches the app into one screenshot case: the fixtures follow `-screenshotCase`, the
    /// language follows the locale, and the receipt is the only real PDF in the shots.
    func launch(_ screenshotCase: String, locale: ScreenshotLocale, receipt: URL) {
        launchArguments = ["-screenshotCase", screenshotCase,
                           "-screenshotAsset", receipt.path(percentEncoded: false)]
            + locale.launchArguments
        launch()
    }

    /// Waits for a text that is only on screen once the shot is ready.
    ///
    /// Both a pushed document and the filled tagging form arrive after the first render, and a
    /// receipt the app cannot read leaves a blank pane in a shot that still reports green - so a
    /// word from the rendered page is what the capture waits for.
    ///
    /// PDF page text and list rows carry their text as the accessibility value while buttons use
    /// the label, so a lookup by identifier alone would miss most of them.
    func waitForVisibleText(_ text: String, timeout: TimeInterval = 30) -> Bool {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", text, text))
            .firstMatch
            .waitForExistence(timeout: timeout)
    }
}

/// The folder the App Store screenshots are written to, shared by both UI test targets.
enum ScreenshotOutput {

    /// Derived from the source location, so a plain Cmd+U lands in the repository with no scheme
    /// environment or sidecar file to configure.
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // UITests Shared
        .deletingLastPathComponent()   // the repository root

    /// Writes one capture as an upload-ready PNG and proves it arrived that way.
    ///
    /// The capture keeps its own pixels: resampling to another accepted size would only soften
    /// the text. A run that silently writes nothing still reports green, so the file is re-read
    /// and checked - the store rejects an alpha channel and every size but its own.
    static func write(_ screenshot: XCUIScreenshot,
                      named name: String,
                      locale: ScreenshotLocale,
                      file: StaticString = #filePath,
                      line: UInt = #line) throws {
        let device = ScreenshotDevice.current
        let outputDirectory = directory(for: locale, device: device)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let capture = try image(from: screenshot.pngRepresentation, file: file, line: line)
        let captureSize = CGSize(width: capture.width, height: capture.height)

        // A landscape iPad still hands out the physical, portrait screen buffer with the content
        // turned inside it - a quarter turn puts it upright without touching a single pixel value.
        let quarterTurn = captureSize == CGSize(width: device.storeSize.height, height: device.storeSize.width)

        // The Mac window is pinned and the simulators are fixed, so a capture is the store size by
        // itself - anything else means the run used the wrong destination or orientation.
        XCTAssertTrue(captureSize == device.storeSize || quarterTurn,
                      "\(capture.width)x\(capture.height) is not the \(device.rawValue) store size",
                      file: file,
                      line: line)

        let url = outputDirectory.appendingPathComponent("\(name).png")
        try writeOpaquePNG(capture, quarterTurn: quarterTurn, to: url, file: file, line: line)

        let written = try properties(of: url, file: file, line: line)
        XCTAssertEqual(written[kCGImagePropertyPixelWidth] as? Int, Int(device.storeSize.width), file: file, line: line)
        XCTAssertEqual(written[kCGImagePropertyPixelHeight] as? Int, Int(device.storeSize.height), file: file, line: line)
        XCTAssertFalse(written[kCGImagePropertyHasAlpha] as? Bool ?? false,
                       "the store rejects an alpha channel",
                       file: file,
                       line: line)
    }

    /// `assets/screenshots/<locale>/<device family>`, the layout the store upload reads.
    private static func directory(for locale: ScreenshotLocale, device: ScreenshotDevice) -> URL {
        repositoryRoot
            .appendingPathComponent("assets/screenshots", isDirectory: true)
            .appendingPathComponent(locale.rawValue, isDirectory: true)
            .appendingPathComponent(device.rawValue, isDirectory: true)
    }

    /// Redraws the capture pixel for pixel onto white, which drops the alpha channel the
    /// screenshot API always hands out. Nothing is resampled: the size only ever swaps its two
    /// axes, and a quarter turn maps whole pixels.
    private static func writeOpaquePNG(_ capture: CGImage,
                                       quarterTurn: Bool,
                                       to url: URL,
                                       file: StaticString,
                                       line: UInt) throws {
        let width = quarterTurn ? capture.height : capture.width
        let height = quarterTurn ? capture.width : capture.height
        let context = try XCTUnwrap(CGContext(data: nil,
                                              width: width,
                                              height: height,
                                              bitsPerComponent: 8,
                                              bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
                                    file: file,
                                    line: line)
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if quarterTurn {
            context.translateBy(x: CGFloat(width), y: 0)
            context.rotate(by: .pi / 2)
        }
        context.draw(capture, in: CGRect(x: 0, y: 0, width: capture.width, height: capture.height))

        let opaqueImage = try XCTUnwrap(context.makeImage(), file: file, line: line)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,
                                                                       UTType.png.identifier as CFString,
                                                                       1,
                                                                       nil),
                                        file: file,
                                        line: line)
        CGImageDestinationAddImage(destination, opaqueImage, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination), file: file, line: line)
    }

    private static func image(from data: Data, file: StaticString, line: UInt) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil), file: file, line: line)
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil), file: file, line: line)
    }

    private static func properties(of url: URL, file: StaticString, line: UInt) throws -> [CFString: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), file: file, line: line)
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                             file: file,
                             line: line)
    }
}
