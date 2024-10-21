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

    var body: some Scene {
        #warning("TODO: also look for more 'TODO:' not in warnings")
        WindowGroup {
            IosSplitNavigation()
                .inAppPurchasesSetup()
                .task(initializePdfArchiver)
        }
        .modelContainer(container)
        .environment(subscription)
    }
}
