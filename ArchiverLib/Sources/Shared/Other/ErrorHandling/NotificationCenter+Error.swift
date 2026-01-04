//
//  NotificationCenter+Error.swift
//  
//
//  Created by Julian Kahnert on 16.12.20.
//

import Combine
import SwiftUI

extension Notification.Name {
    fileprivate static let alertMessage = Notification.Name("Error.Message")
}

extension NotificationCenter {
    public func postAlert(_ error: any Error, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        let defaultTitle = LocalizedStringResource("An error occurred 😳", bundle: #bundle)

        let alertDataModel: AlertDataModel
        if let error = error as? any LocalizedError {
            let title: LocalizedStringResource
            if let errorDescription = error.errorDescription {
                title = LocalizedStringResource(stringLiteral: errorDescription)
            } else {
                title = defaultTitle
            }
            let message = [
                error.failureReason,
                error.recoverySuggestion]
                .compactMap { $0 }
                .joined(separator: "\n\n")

            alertDataModel = AlertDataModel(title: title,
                                            message: LocalizedStringResource(stringLiteral: message),
                                            primaryButton: .init(role: .cancel,
                                                                 action: nil,
                                                                 label: "Cancel"))
        } else {
            alertDataModel = AlertDataModel(title: defaultTitle,
                                            message: "\(error.localizedDescription)\n\n\(String(describing: error))",
                                            primaryButton: .init(role: .cancel,
                                                                 action: nil,
                                                                 label: "Cancel"))
        }
        postAlert(alertDataModel, file: file, function: function, line: line)
    }

    public func createAndPost(title: LocalizedStringResource, message: LocalizedStringResource, primaryButtonTitle: LocalizedStringResource, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        let completion = {}
        let alertDataModel = AlertDataModel(title: title,
                                            message: message,
                                            primaryButton: .init(role: nil,
                                                                 action: completion,
                                                                 label: primaryButtonTitle))
        postAlert(alertDataModel, file: file, function: function, line: line)
    }

    private func postAlert(_ alertDataModel: AlertDataModel, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        post(.init(name: .alertMessage,
                   object: alertDataModel,
                   userInfo: [
                    "file": file,
                    "function": function,
                    "line": line
                   ]))
    }

    func alertStream() -> any AsyncSequence<AlertDataModel, Never> {
        NotificationCenter.default.notifications(named: .alertMessage)
            .compactMap { $0.object as? AlertDataModel }
    }
}
