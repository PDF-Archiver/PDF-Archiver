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

    @State private var subscription = Subscription()
    private var navigationModel: NavigationModel = .shared

    var body: some Scene {
        #warning("TODO: also look for more 'TODO:' not in warnings")
        WindowGroup {
            IosSplitNavigation()
                .inAppPurchasesSetup()
                .task(initializePdfArchiver)
        }
        .environment(navigationModel)
        .modelContainer(container)
        .environment(subscription)
    }
}
