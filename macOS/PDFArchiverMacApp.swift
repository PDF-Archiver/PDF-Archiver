//
//  PDFArchiverMacApp.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

import ArchiverFeatures
import Foundation
import SwiftUI

@main
struct PDFArchiverMacApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
        }

        Settings {
            RootView.settings
        }
    }
}
