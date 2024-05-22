//
//  PDFArchiverMacApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

import Diagnostics
import Foundation
import Logging
import Sentry
import SwiftUI

@main
struct PDFArchiverMacApp: App, Log {
    
    @StateObject var mainNavigationViewModel = MainNavigationViewModel()

    var body: some Scene {
        WindowGroup {
            MacSplitNavigation()
        }
        .modelContainer(container)
        
        Settings {
            SettingsView(viewModel: mainNavigationViewModel.moreViewModel)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .modelContainer(container)
    }
}
