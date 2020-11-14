//
//  Alert.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Logging
import SwiftUI

extension Alert {
    static var log: Logger {
        Logger(label: String(describing: self))
    }

    init(viewModel: AlertDataModel) {
        Self.log.error("An error was presented", metadata: ["type": "custom", "title": "\(viewModel.title)"])

        if let secondaryButton = viewModel.secondaryButton {
            self.init(title: Text(viewModel.title),
                      message: Text(viewModel.message),
                      primaryButton: viewModel.primaryButton,
                      secondaryButton: secondaryButton)
        } else {
            self.init(title: Text(viewModel.title),
                      message: Text(viewModel.message),
                      dismissButton: viewModel.primaryButton)
        }
    }
}
