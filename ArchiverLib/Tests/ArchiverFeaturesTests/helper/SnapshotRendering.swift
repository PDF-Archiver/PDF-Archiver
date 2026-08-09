//
//  SnapshotRendering.swift
//  ArchiverLib
//

import SnapshotTesting
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Antialiasing of text differs slightly between runs, so compare with human-eye tolerance.
private let precision: Float = 0.99
private let perceptualPrecision: Float = 0.98

/// Renders a view and compares it against a committed reference image.
///
/// Both platforms capture through `layer.render(in:)`. The `drawHierarchy(afterScreenUpdates:)`
/// path would handle scene-level presentations too, but it needs a host application, which an SPM
/// test target cannot have - so anything presented as a sheet stays out of reach here.
@MainActor
func assertViewSnapshot(
    of view: some View,
    size: CGSize,
    named name: String? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let suffix: String
    #if os(iOS)
    suffix = "ios"
    #else
    suffix = "macos"
    #endif
    let snapshotName = [name, suffix].compactMap(\.self).joined(separator: "-")

    #if os(iOS)
    assertSnapshot(
        of: view,
        as: .image(
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            layout: .fixed(width: size.width, height: size.height),
            traits: UITraitCollection(userInterfaceStyle: .dark)
        ),
        named: snapshotName,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
    #elseif os(macOS)
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = CGRect(origin: .zero, size: size)

    // Without a window the grouped form style renders its backgrounds as transparent.
    let window = NSWindow(
        contentRect: hostingView.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    // Pin the appearance, otherwise the reference depends on the machine's light/dark setting.
    window.appearance = NSAppearance(named: .darkAqua)
    hostingView.layoutSubtreeIfNeeded()

    // PDFView loads its document asynchronously and would otherwise be captured empty.
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))

    assertSnapshot(
        of: hostingView,
        as: .image(precision: precision, perceptualPrecision: perceptualPrecision),
        named: snapshotName,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
    #endif
}
