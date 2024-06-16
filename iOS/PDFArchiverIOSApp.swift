//
//  PDFArchiverIOSApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 16.06.24.
//

import Foundation
import SwiftUI

@main
struct PDFArchiverIOSApp: App, Log {
    
    @StateObject private var moreViewModel = MoreTabViewModel()
    @State private var subscription = Subscription()

    var body: some Scene {
        WindowGroup {
            IosSplitNavigation()
                .inAppPurchasesSetup()
                .task(Self.initialSetup)
        }
        .modelContainer(container)
        .environment(subscription)
        
//        Settings {
//            SettingsView(viewModel: moreViewModel)
//        }
//        .windowStyle(HiddenTitleBarWindowStyle())
//        .modelContainer(container)
//        .environment(subscription)
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
