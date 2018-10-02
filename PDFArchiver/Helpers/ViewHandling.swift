//
//  ViewHandling.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 06.06.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Quartz

// check dialog window
func dialogOK(messageKey: String, infoKey: String, style: NSAlert.Style) {
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString(messageKey, comment: "")
        alert.informativeText = NSLocalizedString(infoKey, comment: "")
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
