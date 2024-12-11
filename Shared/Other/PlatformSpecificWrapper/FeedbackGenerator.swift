//
//  FeedbackGenerator.swift
//  
//
//  Created by Julian Kahnert on 07.11.20.
//

#if canImport(UIKit)
import UIKit

@MainActor
enum FeedbackGenerator {
    
    enum FeedbackType {
        case success, warning, error
    }

    private static let selectionFeedback = UISelectionFeedbackGenerator()
    private static let notificationFeedback = UINotificationFeedbackGenerator()

    static func selectionChanged() {
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }

    
    static func notify(_ status: FeedbackType) {
        Task {
            await MainActor.run {
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
            }
        }
    }
}
#endif
