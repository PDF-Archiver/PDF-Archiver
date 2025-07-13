//
//  PDFArchiverMacApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

import ArchiverFeatures
import Foundation
import SwiftUI

@main
struct PDFArchiverMacApp: App, Log {

    @StateObject private var moreViewModel = SettingsViewModel()
    private var navigationModel: NavigationModel = .shared

    init() {
//        initializePdfArchiver()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
//            SplitNavigationView()
//                .inAppPurchasesSetup()
        }
//        .environment(navigationModel)
//        .modelContainer(container)

        Settings {
            SettingsViewMacOS(viewModel: moreViewModel)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
//        .environment(navigationModel)
//        .modelContainer(container)
    }
}
