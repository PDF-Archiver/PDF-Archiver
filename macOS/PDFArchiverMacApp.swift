//
//  PDFArchiverMacApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

import AppKit
import ArchiverFeatures
import Foundation
import SwiftUI

@main
struct PDFArchiverMacApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screenshotScene = ScreenshotScene.requested {
                screenshotScene.view
                    .onAppear(perform: sizeWindowForScreenshot)
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
    private func sizeWindowForScreenshot() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.setContentSize(NSSize(width: 1000, height: 620))
        window.center()
    }
    #endif
}
