//
//  PDFArchiverIOSApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 16.06.24.
//

import AppIntents
import Foundation
import SwiftUI

@main
struct PDFArchiverIOSApp: App, Log {

    private let navigationModel: NavigationModel

    init() {
        let model = NavigationModel.shared
        navigationModel = model
        AppDependencyManager.shared.add(dependency: model)
    }

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
