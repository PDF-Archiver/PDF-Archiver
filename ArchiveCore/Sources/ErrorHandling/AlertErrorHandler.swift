//
//  AlertErrorHandler.swift
//  
//
//  Created by Julian Kahnert on 30.10.20.
//
// Source: https://www.swiftbysundell.com/articles/propagating-user-facing-errors-in-swift/

import SwiftUI

public struct AlertErrorHandler: ErrorHandler {
    private struct Presentation: Identifiable {
        let id: UUID
        let error: Error
        let retryHandler: () -> Void
    }

    // We give our handler an ID, so that SwiftUI will be able
    // to keep track of the alerts that it creates as it updates
    // our various views:
    private let id = UUID()

    private let secondaryButton: Alert.Button?

    public init(secondaryButton: Alert.Button? = nil) {
        self.secondaryButton = secondaryButton
    }

    public func handle<T: View>(
        _ error: Error?,
        in view: T,
        retryHandler: @escaping () -> Void
    ) -> AnyView {
//        guard error?.resolveCategory() != .requiresLogout else {
//            return AnyView(view)
//        }

        var presentation = error.map { Presentation(
            id: id,
            error: $0,
            retryHandler: retryHandler
        )}

        // We need to convert our model to a Binding value in
        // order to be able to present an alert using it:
        let binding = Binding(
            get: { presentation },
            set: { presentation = $0 }
        )

        return AnyView(view.alert(item: binding, content: makeAlert))
    }

    private func makeAlert(for presentation: Presentation) -> Alert {
        if let alertDataModel = presentation.error as? AlertDataModel {
            return Alert(viewModel: alertDataModel)

        } else {

            let errorInfo = createErrorInfo(from: presentation.error)

            switch presentation.error.resolveCategory() {
                case .retryable:
                    return Alert(
                        title: Text(errorInfo.title),
                        message: Text(errorInfo.message),
                        primaryButton: .default(Text("Dismiss")),
                        secondaryButton: .default(Text("Retry"),
                                                  action: presentation.retryHandler
                        )
                    )
                case .nonRetryable:
                    if let secondaryButton = secondaryButton {
                        return Alert(
                            title: Text(errorInfo.title),
                            message: Text(errorInfo.message),
                            primaryButton: .default(Text("Dismiss")),
                            secondaryButton: secondaryButton)
                    } else {
                        return Alert(
                            title: Text(errorInfo.title),
                            message: Text(errorInfo.message),
                            dismissButton: .default(Text("Dismiss"))
                        )
                    }

//                case .requiresLogout:
//                    // We don't expect this code path to be hit, since
//                    // we're guarding for this case above, so we'll
//                    // trigger an assertion failure here.
//                    assertionFailure("Should have logged out")
//                    return Alert(title: Text("Logging out..."))
            }
        }
    }

    typealias ErrorInformation = (title: LocalizedStringKey, message: LocalizedStringKey)

    private func createErrorInfo(from error: Error) -> ErrorInformation {
        let defaultTitle = "An error occured 😳"
        if let error = error as? LocalizedError {
            let title = error.errorDescription ?? defaultTitle
            let message = [
                error.failureReason,
                error.recoverySuggestion]
                .compactMap { $0 }
                .joined(separator: "\n\n")

            return (LocalizedStringKey(title), LocalizedStringKey(message))
        } else {
            return (LocalizedStringKey(defaultTitle), LocalizedStringKey("\(error.localizedDescription)\n\n\(String(describing: error))"))
        }
    }
}
