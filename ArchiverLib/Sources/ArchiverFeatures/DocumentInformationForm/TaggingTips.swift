//
//  TaggingTips.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 26.06.25.
//

import TipKit

enum TaggingTips {
    static let size: CGSize = .init(width: 24, height: 24)

    struct Date: Tip {
        var title: Text {
            Text("Date", bundle: #bundle)
        }

        var message: Text? {
            Text("Specify the Date of the Document", bundle: #bundle)
        }

        var image: Image? {
            Image(systemName: "calendar")
        }
    }

    struct Specification: Tip {
        var title: Text {
            Text("Description", bundle: #bundle)
        }

        var message: Text? {
            Text("Meaningful description, e.g. _blue hoodie_", bundle: #bundle)
        }

        var image: Image? {
            Image(systemName: "text.word.spacing")
        }
    }

    struct Tags: Tip {
        var title: Text {
            Text("Tags", bundle: #bundle)
        }

        var message: Text? {
            Text("Tags of the document, e.g. _bill_ and _clothing_", bundle: #bundle)
        }

        var image: Image? {
            Image(systemName: "tag")
        }
    }

    #if os(macOS)
    struct KeyboardShortCut: Tip {
        static let documentSaved = Event(id: "documentSaved")

        var title: Text {
            Text("Keyboard Shortcuts", bundle: #bundle)
        }

        var message: Text? {
            Text("Use keyboard shortcuts to navigate the document information:\n\n**TAB** to move to the next field\n**CMD S** to save the document", bundle: #bundle)
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
}
