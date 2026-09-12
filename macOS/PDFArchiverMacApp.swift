//
//  PDFArchiverMacApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

#if DEBUG
import AppKit
#endif
import ArchiverFeatures
import Foundation
import SwiftUI

@main
struct PDFArchiverMacApp: App {
    init() {
        #if DEBUG
        ScreenshotCase.prepareIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
            #if DEBUG
                .onAppear(perform: sizeWindowForScreenshot)
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
    /// 720 x 450 points, which a Retina display captures as the accepted 1440 x 900 - nothing is
    /// scaled, and the smaller window is what makes the app's text readable at store size. Set
    /// here rather than via `defaultSize`, which a saved frame overrides.
    private func sizeWindowForScreenshot() {
        guard ScreenshotCase.requested != nil,
              let window = NSApplication.shared.windows.first else { return }
        window.setContentSize(NSSize(width: 720, height: 450))
        window.center()

        // A window capture takes whatever is on screen in that rectangle, so the run has to own
        // it - otherwise another app's window ends up inside the store screenshot. `.floating` is
        // not enough: other apps use that level for their panels too.
        window.level = .popUpMenu
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }
    #endif
}
