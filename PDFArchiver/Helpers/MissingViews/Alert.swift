//
//  Alert.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

extension Alert {
    init(viewModel: AlertViewModel?) {
        if let viewModel = viewModel {
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
        } else {
            self.init(title: Text("Something went wrong!"),
                      message: Text("Please try again and contact support if the problem occurs again."),
                      dismissButton: .default(Text("OK")))
        }
    }
}
