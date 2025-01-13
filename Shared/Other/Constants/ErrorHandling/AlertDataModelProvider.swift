//
//  AlertDataModelProvider.swift
//
//
//  Created by Julian Kahnert on 16.12.20.
//

import SwiftUI

struct AlertDataModelProvider: ViewModifier, Log {
    @State private var alertDataModel: AlertDataModel?

    private var isPresented: Binding<Bool> {
        Binding<Bool>(get: {
            alertDataModel != nil
        }, set: { _ in
            alertDataModel = nil
        })
    }

    func body(content: Content) -> some View {
        content
            .task {
                let alertDataModelStream = NotificationCenter.default.alertStream()
                for await alertDataModel in alertDataModelStream {
                    self.alertDataModel = alertDataModel
                }
            }
            .alert(alertDataModel?.title ?? "Error",
                   isPresented: isPresented,
                   presenting: alertDataModel) { viewModel in

                Button(role: viewModel.primaryButton.role) {
                    if let action = viewModel.primaryButton.action {
                        action()
                    }
                    alertDataModel = nil
                } label: {
                    Text(viewModel.primaryButton.label)
                }
            } message: { viewModel in
                Text(viewModel.message)
            }

    }
}
