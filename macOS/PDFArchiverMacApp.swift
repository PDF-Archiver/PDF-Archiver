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
    
    @StateObject var mainNavigationViewModel = MainNavigationViewModel()
    @State private var subscription = Subscription()

    var body: some Scene {
        WindowGroup {
            MacSplitNavigation()
                .inAppPurchasesSetup()
        }
        .modelContainer(container)
        .environment(subscription)
        
        Settings {
            SettingsView(viewModel: mainNavigationViewModel.moreViewModel)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .modelContainer(container)
        .environment(subscription)
    }
}
