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
        #warning("TODO: add appdependency for Intents!?")
//        AppDependencyManager.shared.add(dependency: NavigationModel.shared)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
