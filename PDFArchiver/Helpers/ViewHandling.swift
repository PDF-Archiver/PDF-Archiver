//
//  ViewHandling.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 06.06.18.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
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

func dialog(_ error: Error, style: NSAlert.Style) {
    DispatchQueue.main.async {

        var messageText: String = NSLocalizedString("error_message_fallback", comment: "Fallback when no localized error was found.")
        var informativeText = error.localizedDescription
        if let error = error as? LocalizedError {
            informativeText = [
                error.failureReason,
                error.recoverySuggestion
            ].compactMap { $0 }
                .joined(separator: "\n\n")

            if let errorDescription = error.errorDescription {
                messageText = errorDescription
            }
        }

        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
