//
//  AlertDataModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import SwiftUI

public struct AlertDataModel: Error, Identifiable {
    public let id = UUID()
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
}

extension AlertDataModel {

    public static func createAndPost(title: LocalizedStringKey, message: LocalizedStringKey, primaryButtonTitle: LocalizedStringKey, completion: (() -> Void)? = nil) -> Error {

        let primaryButton: Alert.Button
        if let completion = completion {
            primaryButton = .default(Text(primaryButtonTitle),
                                     action: completion)
        } else {
            primaryButton = .default(Text(primaryButtonTitle))
        }
        return AlertDataModel(title: title,
                                       message: message,
                                       primaryButton: primaryButton,
                                       secondaryButton: nil)
    }

    public static func createAndPost(title: LocalizedStringKey, message: LocalizedStringKey, primaryButton: Alert.Button, secondaryButton: Alert.Button) -> Error {
        return AlertDataModel(title: title,
                                       message: message,
                                       primaryButton: primaryButton,
                                       secondaryButton: secondaryButton)
    }

    public static func createAndPostNoICloudDrive() -> Error {
        return createAndPost(title: "Attention",
                      message: "Could not find iCloud Drive.",
                      primaryButtonTitle: "OK")
    }
}
