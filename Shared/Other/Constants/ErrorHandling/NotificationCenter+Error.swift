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
    public func postAlert(_ error: Error, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        let defaultTitle = "An error occurred 😳"

        let alertDataModel: AlertDataModel
        if let error = error as? LocalizedError {
            let title = LocalizedStringKey(error.errorDescription ?? defaultTitle)
            let message = [
                error.failureReason,
                error.recoverySuggestion]
                .compactMap { $0 }
                .joined(separator: "\n\n")

            alertDataModel = AlertDataModel(title: title,
                                            message: LocalizedStringKey(message),
                                            primaryButton: .default(Text("Dismiss")),
                                            secondaryButton: nil)
        } else {
            alertDataModel = AlertDataModel(title: LocalizedStringKey(defaultTitle),
                                            message: "\(error.localizedDescription)\n\n\(String(describing: error))",
                                            primaryButton: .default(Text("Dismiss")),
                                            secondaryButton: nil)
        }
        postAlert(alertDataModel, file: file, function: function, line: line)
    }

    public func createAndPost(title: LocalizedStringKey, message: LocalizedStringKey, primaryButtonTitle: LocalizedStringKey, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        let completion = {}
        let alertDataModel = AlertDataModel(title: title,
                                            message: message,
                                            primaryButton: .default(Text(primaryButtonTitle),
                                                                    action: completion),
                                            secondaryButton: nil)
        postAlert(alertDataModel, file: file, function: function, line: line)
    }

    public func createAndPost(title: LocalizedStringKey, message: LocalizedStringKey, primaryButton: Alert.Button, secondaryButton: Alert.Button, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        let alertDataModel = AlertDataModel(title: title,
                                            message: message,
                                            primaryButton: primaryButton,
                                            secondaryButton: secondaryButton)
        postAlert(alertDataModel, file: file, function: function, line: line)
    }

    public func createAndPostNoICloudDrive(completion: @escaping () -> Void) {
        createAndPost(title: "Attention",
                      message: "Could not find iCloud Drive.",
                      primaryButtonTitle: "OK")
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

    public func alertPublisher() -> AnyPublisher<AlertDataModel?, Never> {
        publisher(for: .alertMessage)
            .compactMap { $0.object as? AlertDataModel }
            .map { Optional($0) }
            .eraseToAnyPublisher()
    }
}
