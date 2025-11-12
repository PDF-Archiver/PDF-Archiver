//
//  OnboardingTips.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 17.04.25.
//

import SwiftUI
import TipKit

public struct ScanShareTip: Tip {
    public init() {}
    public var title: Text {
        #if os(macOS)
        Text("Import Document", bundle: #bundle)
        #else
        Text("Scan Document", bundle: #bundle)
        #endif
    }

    public var message: Text? {
            #if os(macOS)
            Text("**Drag and drop** a PDF document to this area to import it.\n\nOr **click** here to open the file browser.", bundle: #bundle)
            #else
            Text("**Tap** short to start scanning a document.\n\n**Long press** to scan and share the document after processing.", bundle: #bundle)
            #endif
    }

    public var image: Image? {
        Image(systemName: "text.document")
    }

    public var actions: [Action] {
        #if os(macOS)
        []
        #else
        [
        Action(id: "scan", title: String(localized: "Scan", bundle: #bundle)),
        Action(id: "scanAndShare", title: String(localized: "Scan & Share", bundle: #bundle))
        ]
        #endif
    }
}

public struct AfterFirstImportTip: Tip {
    public init() {}
    public static let documentImported = Tips.Event(id: "documentImported")

    public var title: Text {
        Text("New Document", bundle: #bundle)
    }

    public var message: Text? {
        Text("Your first document was imported. Switch to **Inbox** to see and archive it.", bundle: #bundle)
    }

    public var image: Image? {
        Image(systemName: "arrow.down.document")
    }

    public var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }

    public var rules: [Rule] {
        // Tip will only display when the landmarksAppDidOpen event has been donated 3 or more times in the last week.
        #Rule(Self.documentImported) {
            $0.donations.count >= 1
        }
    }
}
