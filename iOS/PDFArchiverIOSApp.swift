//
//  PDFArchiverIOSApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 16.06.24.
//

import ArchiverDatabase
import ArchiverFeatures
import ComposableArchitecture
import Foundation
import SwiftUI

@main
struct PDFArchiverIOSApp: App {
    init() {
        // One block, in this order: the screenshot run has to switch the context to `.preview`
        // before the database is prepared, and can only seed it afterwards.
        prepareDependencies { values in
            #if DEBUG
            ScreenshotCase.prepareOverrides(&values)
            #endif
            withErrorReporting {
                try values.bootstrapDatabase()
                #if DEBUG
                try ScreenshotCase.seedDatabase(values)
                #endif
            }
        }

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
