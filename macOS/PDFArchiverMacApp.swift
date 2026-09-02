//
//  PDFArchiverMacApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

import AppKit
import ArchiverFeatures
import ArchiverModels
import Foundation
import OSLog
import ScreenCaptureKit
import SwiftUI

@main
struct PDFArchiverMacApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screenshotScene = ScreenshotScene.requested {
                screenshotScene.view
                    .onAppear(perform: prepareScreenshotWindow)
            } else {
                RootView()
            }
            #else
            RootView()
            #endif
        }
        .commands {
            DocumentCommands()
        }

        Settings {
            RootView.settings
        }
    }

    #if DEBUG
    /// Small enough that a 1x capture fits a 1440 x 900 store canvas at full size, leaving room
    /// for the caption. Set here rather than via `defaultSize`, which a saved frame overrides.
    ///
    /// With `-screenshotOutput <path>` the window is also written there and the app quits.
    private func prepareScreenshotWindow() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.setContentSize(NSSize(width: 1000, height: 620))
        window.center()

        guard let output = UserDefaults.standard.string(forKey: "screenshotOutput") else { return }
        Task { @MainActor in
            // The sidebar and its glass settle a few frames after the window appears.
            try? await Task.sleep(for: .seconds(3))
            await captureWindow(window, to: URL(filePath: output))
            NSApplication.shared.terminate(nil)
        }
    }

    /// Reads the composited window instead of drawing the view tree: `cacheDisplay` cannot
    /// traverse the macOS 26 glass sidebar and renders it as a blank white block.
    ///
    /// Needs Screen Recording permission for this app — macOS asks once on the first run.
    private func captureWindow(_ window: NSWindow, to url: URL) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let target = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
                Logger.app.error("Screenshot capture could not find the app window - is Screen Recording allowed?")
                return
            }

            let configuration = SCStreamConfiguration()
            configuration.width = Int(target.frame.width)
            configuration.height = Int(target.frame.height)
            configuration.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: target),
                configuration: configuration)

            guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                Logger.app.error("Screenshot capture could not encode the window image")
                return
            }
            try data.write(to: url)
        } catch {
            Logger.app.error("Screenshot capture failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    #endif
}
