//
//  PDFArchiverIOSApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 16.06.24.
//

import ArchiverFeatures
import Foundation
import SwiftUI

@main
struct PDFArchiverIOSApp: App {
    init() {
        // BGTaskScheduler requires all launch handlers to be registered
        // before the end of the app launch sequence
        if #available(iOS 26, *) {
            BackgroundTaskManager.registerTaskHandlers()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
