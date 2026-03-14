//
//  PDFArchiverIOSApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 16.06.24.
//

import AppIntents
import ArchiverFeatures
import Foundation
import SwiftUI

@main
struct PDFArchiverIOSApp: App {
    init() {
        AppDependencyManager.shared.add(dependency: IntentNavigationModel.shared)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
