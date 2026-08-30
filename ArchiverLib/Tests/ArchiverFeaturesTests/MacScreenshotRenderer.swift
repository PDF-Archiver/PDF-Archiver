#if os(macOS)
import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import ArchiverFeatures

/// Renders the macOS App Store screenshots straight from a `ScreenshotScene`.
///
/// Unlike iOS, AppKit renders a hosting view offscreen without a window scene, so this needs no
/// running app and no screen recording permission. It only runs when `SCREENSHOT_OUTPUT_DIR`
/// names a destination folder, so a normal test run is unaffected.
///
/// Known gap: `cacheDisplay` cannot capture `NSVisualEffectView`, so the sidebar comes out blank
/// white. A screenshot that needs the sidebar has to come from the running app instead.
@MainActor
struct MacScreenshotRenderer {
    /// 1440 x 900 points at 2x is 2880 x 1800, the largest size the Mac App Store accepts.
    private static let points = CGSize(width: 1440, height: 900)
    private static let scale = 2

    @Test(.enabled(if: outputDirectory != nil))
    func mac() throws {
        // The preview context supplies working dependencies; the test context leaves the
        // import closures unimplemented, and the app calls them while the view settles.
        try withDependencies {
            $0.context = .preview
        } operation: {
            try render(ScreenshotScene.mac.view, named: "01-archive")
        }
    }

    private func render(_ view: some View, named name: String) throws {
        let directory = try #require(Self.outputDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try #require(image(of: view).representation(using: .png, properties: [:]))
        try data.write(to: directory.appending(component: "\(name).png"))
    }

    private func image(of view: some View) throws -> NSBitmapImageRep {
        let bounds = CGRect(origin: .zero, size: Self.points)
        let hosting = NSHostingView(rootView: view.frame(width: bounds.width, height: bounds.height))
        hosting.frame = bounds

        let window = NSWindow(contentRect: bounds, styleMask: [.titled], backing: .buffered, defer: false)
        // Pin the appearance so the render does not follow whoever runs it.
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        hosting.layoutSubtreeIfNeeded()

        // SwiftUI commits its content on the next run loop turn, not during layout.
        RunLoop.current.run(until: Date().addingTimeInterval(2))

        // `bitmapImageRepForCachingDisplay` follows the offscreen window's 1x backing, so the
        // representation is built by hand to get the 2x pixels the App Store wants.
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil,
                                                pixelsWide: Int(bounds.width) * Self.scale,
                                                pixelsHigh: Int(bounds.height) * Self.scale,
                                                bitsPerSample: 8,
                                                samplesPerPixel: 4,
                                                hasAlpha: true,
                                                isPlanar: false,
                                                colorSpaceName: .deviceRGB,
                                                bytesPerRow: 0,
                                                bitsPerPixel: 0))
        rep.size = bounds.size
        hosting.cacheDisplay(in: bounds, to: rep)
        return rep
    }

    nonisolated private static var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"].map { URL(filePath: $0) }
    }
}
#endif
