//
//  TaggingTips.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 26.06.25.
//

import TipKit

enum TaggingTips {
    static let size: CGSize = .init(width: 24, height: 24)

    @MainActor
    struct Date: @preconcurrency Tip {
        var title: Text {
            Text("Date", bundle: .module)
        }

        var message: Text? {
            Text("Specify the Date of the Document", bundle: .module)
        }

        var image: Image? {
            Image(systemName: "calendar")
        }
    }

    @MainActor
    struct Specification: @preconcurrency Tip {
        var title: Text {
            Text("Description", bundle: .module)
        }

        var message: Text? {
            Text("Meaningful description, e.g. _blue hoodie_", bundle: .module)
        }

        var image: Image? {
            Image(systemName: "text.word.spacing")
        }
    }

    @MainActor
    struct Tags: @preconcurrency Tip {
        var title: Text {
            Text("Tags", bundle: .module)
        }

        var message: Text? {
            Text("Tags of the document, e.g. _bill_ and _clothing_", bundle: .module)
        }

        var image: Image? {
            Image(systemName: "tag")
        }
    }

    #if os(macOS)
    @MainActor
    struct KeyboardShortCut: @preconcurrency Tip {
        static let documentSaved = Event(id: "documentSaved")

        var title: Text {
            Text("Keyboard Shortcuts", bundle: .module)
        }

        var message: Text? {
            Text("Use keyboard shortcuts to navigate the document information:\n\n**TAB** to move to the next field\n**CMD S** to save the document", bundle: .module)
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
