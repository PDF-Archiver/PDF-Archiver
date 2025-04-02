//
// Copyright (c) Vatsal Manot
//
// Source: https://github.com/SwiftUIX/SwiftUIX/blob/acff7a62c0607346f9ce9aaa6f56d0e008f506a5/Sources/SwiftUIX/Intramodular/App%20Activities/AppActivityView.swift

import Swift
import SwiftUI

#if os(iOS) || targetEnvironment(macCatalyst)
struct AppActivityView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIActivityViewController

    private let activityItems: [Any]
    private let applicationActivities: [UIActivity]?

    private var excludedActivityTypes: [UIActivity.ActivityType] = []

    private var onCancel: () -> Void = { }
    private var onComplete: (Result<(activity: UIActivity.ActivityType, items: [Any]?), Error>) -> Void = { _ in }

    init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }

    func makeUIViewController(context: Context) -> UIViewControllerType {
        let viewController = UIViewControllerType(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )

        viewController.excludedActivityTypes = excludedActivityTypes

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        uiViewController.excludedActivityTypes = excludedActivityTypes

        uiViewController.completionWithItemsHandler = { activity, success, items, error in
            if let error = error {
                self.onComplete(.failure(error))
            } else if let activity = activity, success {
                self.onComplete(.success((activity, items)))
            } else if !success {
                self.onCancel()
            } else {
                assertionFailure()
            }
        }
    }

    static func dismantleUIViewController(_ uiViewController: UIViewControllerType, coordinator: Coordinator) {
        uiViewController.completionWithItemsHandler = nil
    }
}
#endif
