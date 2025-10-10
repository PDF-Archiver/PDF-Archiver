//
//  OnboardingTips.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 17.04.25.
//

import SwiftUI
import TipKit

// TODO: Add first document after it has been scanned
// enum AfterFirstPdfTips: Tip {
//    case archive
// }

public struct ScanShareTip: Tip {
    public init() {}
    public var title: Text {
        #if os(macOS)
        Text("Import Document", bundle: .module)
        #else
        Text("Scan Document", bundle: .module)
        #endif
    }

    public var message: Text? {
            #if os(macOS)
            Text("**Drag and drop** a PDF document to this area to import it.\n\nOr **click** here to open the file browser.", bundle: .module)
            #else
            Text("**Tap** short to start scanning a document.\n\n**Long press** to scan and share the document after processing.", bundle: .module)
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
        Action(id: "scan", title: String(localized: "Scan", bundle: .module)),
        Action(id: "scanAndShare", title: String(localized: "Scan & Share", bundle: .module))
        ]
        #endif
    }
}

public struct AfterFirstImportTip: Tip {
    public init() {}
    public static let documentImported = Tips.Event(id: "documentImported")

    public var title: Text {
        Text("New Document", bundle: .module)
    }

    public var message: Text? {
        Text("Your first document was imported. Switch to **Inbox** to see and archive it.", bundle: .module)
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
