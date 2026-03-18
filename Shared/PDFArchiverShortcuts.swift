//
//  PDFArchiverShortcuts.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.03.26.
//

import AppIntents

struct PDFArchiverShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanDocument(),
            phrases: [
                "Scan with \(.applicationName)",
                "Scan a document with \(.applicationName)",
                "Scanne mit \(.applicationName)",
                "Dokument scannen mit \(.applicationName)"
            ],
            shortTitle: "Scan",
            systemImageName: "doc.viewfinder"
        )
        AppShortcut(
            intent: ScanAndShareDocument(),
            phrases: [
                "Scan and share with \(.applicationName)",
                "Scanne und teile mit \(.applicationName)"
            ],
            shortTitle: "Scan & Share",
            systemImageName: "doc.viewfinder.fill"
        )
    }
}
