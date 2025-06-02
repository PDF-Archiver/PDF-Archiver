//
//  AppShortcut.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.05.25.
//

import AppIntents
import Foundation

class AppShortcuts: AppShortcutsProvider {

    /// The color the system uses to display the App Shortcuts in the Shortcuts app.
    static let shortcutTileColor = ShortcutTileColor.yellow

    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ScanDocument(), phrases: [
            "Scan a document with \(.applicationName)"
        ],
        shortTitle: "Scan",
        systemImageName: "document.viewfinder")

        AppShortcut(intent: ScanAndShareDocument(), phrases: [
            "Scan and share a document with \(.applicationName)"
        ],
        shortTitle: "Scan & Share",
        systemImageName: "square.and.arrow.up")
    }
}
