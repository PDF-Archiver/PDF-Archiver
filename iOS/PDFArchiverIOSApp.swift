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

//    @StateObject private var moreViewModel = MoreTabViewModel()
    @State private var subscription = Subscription()

    var body: some Scene {
        WindowGroup {
            IosSplitNavigation()
                .inAppPurchasesSetup()
                .task(initializePdfArchiver)
        }
        .modelContainer(previewContainer)
        .environment(subscription)
    }
}
