//
//  OnboardingTips.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 17.04.25.
//

import SwiftUI
import TipKit

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
            Text("Drag and drop a PDF document to this area to import it.\n\nOr click here to open the file browser.")
            #else
            Text("Tap short to start scanning a document.\n\nLong press to scan and share the document after processing.")
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

#if os(macOS)
struct TaggingShortCutTip: Tip {
    static let documentSaved = Event(id: "documentSaved")

    var title: Text {
            Text("Keyboard Shortcuts")
    }

    var message: Text? {
            Text("Use keyboard shortcuts to navigate the document information:\n\n**TAB** to move to the next field\n**CMD S** to save the document")
    }

    var image: Image? {
        Image(systemName: "keyboard")
    }

    var options: [any TipOption] {
        [MaxDisplayCount(2)]
    }

    var rules: [Rule] {
        #Rule(Self.documentSaved) {
            $0.donations.donatedWithin(.hour).count == 2
        }
    }
}
#endif
