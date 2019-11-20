//
//  AlertViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct AlertViewModel {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?

    static func createAndPost(title: LocalizedStringKey, message: LocalizedStringKey, primaryButtonTitle: LocalizedStringKey) {
        let viewModel = AlertViewModel(title: title,
                                       message: message,
                                       primaryButton: .default(Text(primaryButtonTitle)),
                                       secondaryButton: nil)
        NotificationCenter.default.post(name: .showError, object: viewModel)
    }

    static func createAndPost(title predefinedTitle: LocalizedStringKey? = nil, message error: Error, primaryButtonTitle: LocalizedStringKey) {
        let defaultTitle = "Something went wrong!"
        let title: String
        let message: String
        if let error = error as? LocalizedError {
            title = error.errorDescription ?? defaultTitle
            message = [
                error.failureReason,
                error.recoverySuggestion]
                .compactMap { $0 }
                .joined(separator: "\n\n")
        } else {
            title = defaultTitle
            message = error.localizedDescription
        }

        let viewModel = AlertViewModel(title: predefinedTitle ?? LocalizedStringKey(title),
                                       message: LocalizedStringKey(message),
                                       primaryButton: .default(Text(primaryButtonTitle)),
                                       secondaryButton: nil)
        NotificationCenter.default.post(name: .showError, object: viewModel)
    }

    static func createAndPost(title: LocalizedStringKey, message: LocalizedStringKey, primaryButton: Alert.Button, secondaryButton: Alert.Button) {
        let viewModel = AlertViewModel(title: title,
                                       message: message,
                                       primaryButton: primaryButton,
                                       secondaryButton: secondaryButton)
        NotificationCenter.default.post(name: .showError, object: viewModel)
    }
}
