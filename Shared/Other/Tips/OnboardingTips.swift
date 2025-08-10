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

struct ScanShareTip: Tip {
    var title: Text {
        #if os(macOS)
        Text("Import Document")
        #else
        Text("Scan Document")
        #endif
    }

    var message: Text? {
            #if os(macOS)
            Text("**Drag and drop** a PDF document to this area to import it.\n\nOr **click** here to open the file browser.")
            #else
            Text("**Tap** short to start scanning a document.\n\n**Long press** to scan and share the document after processing.")
            #endif
    }

    var image: Image? {
        Image(systemName: "text.document")
    }

    var actions: [Action] {
        #if os(macOS)
        []
        #else
        [
        Action(id: "scan", title: "Scan"),
        Action(id: "scanAndShare", title: "Scan & Share")
        ]
        #endif
    }
}

struct UntaggedViewTip: Tip {
    var title: Text {
        Text("Tagging View")
    }

    var message: Text? {
        Text("Tap here to see a list of your untagged documents.\nThey can be found in your archive view after tagging.")
    }

    var image: Image? {
        Image(systemName: "tag")
    }
}

struct AfterFirstImportTip: Tip {
    static let documentImported = Tips.Event(id: "documentImported")

    var title: Text {
        Text("New Document")
    }

    var message: Text? {
        Text("Your first document was imported. **Tap here** to see and archive it.")
    }

    var image: Image? {
        Image(systemName: "arrow.down.document")
    }

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }

    var rules: [Rule] {
        // Tip will only display when the landmarksAppDidOpen event has been donated 3 or more times in the last week.
        #Rule(Self.documentImported) {
            $0.donations.count >= 1
        }
    }}
