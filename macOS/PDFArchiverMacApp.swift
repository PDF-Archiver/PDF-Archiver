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
    @State private var subscription = Subscription()
    private var navigationModel: NavigationModel = .shared

    var body: some Scene {
        WindowGroup {
            SplitNavigationView()
                .inAppPurchasesSetup()
                .task(initializePdfArchiver)
        }
        .environment(navigationModel)
        .modelContainer(container)
        .environment(subscription)

        Settings {
            SettingsView(viewModel: moreViewModel)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .modelContainer(container)
        .environment(subscription)
    }
}
