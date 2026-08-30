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
    /// 1440 x 900 points is 2880 x 1800 on a Retina display - the largest size the Mac App Store
    /// takes. Set here rather than via `defaultSize`, which a saved window frame overrides.
    private func sizeWindowForScreenshot() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.setContentSize(NSSize(width: 1440, height: 900))
        window.center()
    }
    #endif
}
