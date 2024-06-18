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

    @StateObject private var moreViewModel = MoreTabViewModel()
    @State private var subscription = Subscription()

    var body: some Scene {
        WindowGroup {
            MacSplitNavigation()
                .inAppPurchasesSetup()
                .task(initializePdfArchiver)
        }
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
