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

    private var navigationModel: NavigationModel = .shared

    var body: some Scene {
        WindowGroup {
            SplitNavigationView()
                .inAppPurchasesSetup()
                .task(initializePdfArchiver)
        }
        .environment(navigationModel)
        .modelContainer(container)
    }
}
