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
                .task(Self.initialSetup)
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
    
    @Sendable
    static func initialSetup() async {
        Task.detached(priority: .userInitiated) {
            do {
                try await NewArchiveStore.shared.reloadArchiveDocuments()
            } catch {
                NotificationCenter.default.postAlert(error)
            }
        }
    }
}
