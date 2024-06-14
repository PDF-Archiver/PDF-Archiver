//
//  FeedbackGenerator.swift
//  
//
//  Created by Julian Kahnert on 07.11.20.
//

#if canImport(UIKit)
import UIKit
#endif

enum FeedbackGenerator {

    enum FeedbackType {
        case success, warning, error
    }

    #if canImport(UIKit)
    private static let notificationFeedback = UINotificationFeedbackGenerator()
    private static let selectionFeedback = UISelectionFeedbackGenerator()
    #endif

    static func selectionChanged() {
        #if canImport(UIKit)
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
        #endif
    }

    static func notify(_ status: FeedbackType) {
        #if canImport(UIKit)
        notificationFeedback.prepare()

        let type: UINotificationFeedbackGenerator.FeedbackType
        switch status {
        case .success:
            type = .success
        case .warning:
            type = .warning
        case .error:
            type = .error
        }
        notificationFeedback.notificationOccurred(type)
        #endif
    }
}
