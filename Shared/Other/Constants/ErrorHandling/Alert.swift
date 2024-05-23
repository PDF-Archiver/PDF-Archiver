//
//  Alert.swift
//  
//
//  Created by Julian Kahnert on 16.12.20.
//

import SwiftUI

extension Alert: Log {
    static func create(from viewModel: AlertDataModel) -> Alert {
        Self.log.error("An error was presented", metadata: ["type": "custom", "title": "\(viewModel.title)"])

        if let secondaryButton = viewModel.secondaryButton {
            return Alert(title: Text(viewModel.title),
                         message: Text(viewModel.message),
                         primaryButton: viewModel.primaryButton,
                         secondaryButton: secondaryButton)
        } else {
            return Alert(title: Text(viewModel.title),
                         message: Text(viewModel.message),
                         dismissButton: viewModel.primaryButton)
        }
    }
}
