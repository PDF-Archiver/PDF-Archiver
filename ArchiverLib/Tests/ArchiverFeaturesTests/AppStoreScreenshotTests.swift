//
//  AppStoreScreenshotTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 02.09.26.
//

import ComposableArchitecture
import Foundation
import SnapshotTesting
import SwiftUI
import Testing

@testable import ArchiverFeatures

/// Renders every `ScreenshotScene` at the pixel size its App Store bucket requires.
///
/// Runs only when an output directory is configured, so a normal test run is unaffected. Drop
/// the `.enabled(if:)` traits to turn these into a layout guard as well — that means committing
/// a reference PNG per screen, which then has to be re-recorded on every OS update.
///
/// iOS only. An offscreen render cannot reproduce the macOS 26 glass sidebar — `cacheDisplay`
/// does not traverse it and leaves a blank white block — so the Mac shots come from the running
/// app instead, via `scripts/capture-mac-screenshots.sh`.
@MainActor
struct AppStoreScreenshotTests {
    /// Shot numbers follow the marketing shot list, which is why they skip: 03, 04, 06 and 07
    /// are camera, Spotlight, Files and home screen, none of which a render can produce. The
    /// 2x numbers are press-kit shots that the store series does not use.
    nonisolated static let mobileScenes: [(ScreenshotScene, String)] = [
        (.archive, "01-archive"),
        (.tagging, "02-tagging"),
        (.storage, "05-on-device"),
        (.trial, "08-trial"),
        (.inbox, "20-inbox"),
        (.statistics, "21-statistics")
    ]

    init() {
        // The scenes read the receipt through UserDefaults, the way the app does from its
        // launch argument.
        if let asset = screenshotAssetPath() {
            UserDefaults.standard.set(asset, forKey: "screenshotAsset")
        }
    }

    #if os(iOS)
    @Test(.enabled(if: screenshotOutputDirectory() != nil), arguments: mobileScenes)
    func iPhone(scene: ScreenshotScene, named name: String) throws {
        let file = try render(scene,
                              as: .image(layout: .fixed(width: StoreSize.iPhone69.width,
                                                        height: StoreSize.iPhone69.height),
                                         traits: storeTraits(displayScale: 3)),
                              device: "iphone-6-9",
                              named: name)
        #expect(try pixelSize(of: file) == CGSize(width: 1320, height: 2868))
    }

    @Test(.enabled(if: screenshotOutputDirectory() != nil), arguments: mobileScenes)
    func iPad(scene: ScreenshotScene, named name: String) throws {
        let file = try render(scene,
                              as: .image(layout: .fixed(width: StoreSize.iPad13.width,
                                                        height: StoreSize.iPad13.height),
                                         traits: storeTraits(displayScale: 2)),
                              device: "ipad-13",
                              named: name)
        #expect(try pixelSize(of: file) == CGSize(width: 2064, height: 2752))
    }

    private func render(_ scene: ScreenshotScene,
                        as snapshotting: Snapshotting<AnyView, UIImage>,
                        device: String,
                        named name: String,
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> URL {
        // The preview context supplies working dependencies; the test context leaves the import
        // closures unimplemented, and the scenes call them while the view settles.
        withDependencies {
            $0.context = .preview
        } operation: {
            capture(AnyView(storeStyled(scene)), as: snapshotting, device: device, screen: name)
        }
    }
    #endif

    /// The store series is captured in dark mode so the screen blends into the dark surround the
    /// framing step draws around it.
    private func storeStyled(_ scene: ScreenshotScene) -> some View {
        scene.view
            .environment(\.colorScheme, .dark)
            .background(Color.black)
    }
}
