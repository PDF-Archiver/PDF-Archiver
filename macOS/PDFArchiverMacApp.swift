//
//  PDFArchiverMacApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

import Foundation
import SwiftUI

@main
struct PDFArchiverMacApp: App, Log {

    @StateObject private var moreViewModel = SettingsViewModel()
    private var navigationModel: NavigationModel = .shared

    var body: some Scene {
        WindowGroup {
            SplitNavigationView()
                .inAppPurchasesSetup()
                .task(initializePdfArchiver)
        }
        .environment(navigationModel)
        .modelContainer(container)

        Settings {
            SettingsView(viewModel: moreViewModel)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .environment(navigationModel)
        .modelContainer(container)
    }
}
