//
//  ArchiverTips.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 17.04.25.
//

import SwiftUI
import TipKit

enum ArchiverTips: Tip {
    case dropButton
    #if os(macOS)
    case saveDocumentInformation
    #endif
    
    var title: Text {
        switch self {
        case .dropButton:
            #if os(macOS)
            Text("Import Document")
            #else
            Text("Scan Document")
            #endif
        
        #if os(macOS)
        case .saveDocumentInformation:
            Text("Keyboard Shortcuts")
        #endif
        }
    }
    
    var message: Text? {
        switch self {
        case .dropButton:
            #if os(macOS)
            Text("Drag and drop a PDF document to this area to import it.\n\nOr click here to open the file browser.")
            #else
            Text("Tap short to start scanning a document.\n\nLong press to scan and share the document after processing.")
            #endif
        
        #if os(macOS)
        case .saveDocumentInformation:
            Text("Use keyboard shortcuts to navigate the document information:\n\n**TAB** to move to the next field\n**CMD S** to save the document")
        #endif
        }
    }
    
    var image: Image? {
        switch self {
        case .dropButton: nil
        #if os(macOS)
        case .saveDocumentInformation: Image(systemName: "keyboard")
//        case .saveDocumentInformation: nil
        #endif
        }
    }
    
    var actions: [Action] {
        switch self {
        #if os(macOS)
        case .dropButton: []
        #else
        case .dropButton: [
            Action(id: "scan", title: "Scan"),
            Action(id: "scanAndShare", title: "Scan & Share")
        ]
        #endif
        #if os(macOS)
        case .saveDocumentInformation: []
        #endif
        }
    }
}
