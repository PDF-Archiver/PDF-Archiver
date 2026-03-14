//
//  PDFArchiverMacApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

import AppIntents
import ArchiverFeatures
import Foundation
import SwiftUI

@main
struct PDFArchiverMacApp: App {
    init() {
        AppDependencyManager.shared.add(dependency: IntentNavigationModel.shared)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }

        Settings {
            RootView.settings
        }
    }
}
