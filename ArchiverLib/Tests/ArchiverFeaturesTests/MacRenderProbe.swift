#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import ArchiverFeatures

// SCREENSHOT-PROBE: temporary, delete after deciding how macOS screenshots are captured
@MainActor
struct MacRenderProbe {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MAC_PROBE_DIR"] != nil))
    func rendersOffscreen() throws {
        let directory = try #require(ProcessInfo.processInfo.environment["MAC_PROBE_DIR"]
            .map { URL(fileURLWithPath: $0) })
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let size = CGSize(width: 1440, height: 900)
        let hosting = NSHostingView(rootView: ScreenshotScene.archive.view.frame(width: size.width, height: size.height))
        hosting.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(contentRect: hosting.frame,
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        let data = try #require(rep.representation(using: .png, properties: [:]))
        try data.write(to: directory.appending(component: "mac-probe.png"))
        Issue.record("SCREENSHOT-PROBE wrote \(rep.pixelsWide)x\(rep.pixelsHigh)")
    }
}
#endif
