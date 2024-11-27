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

#if canImport(UIKit)
    @MainActor
    private static let selectionFeedback = UISelectionFeedbackGenerator()
#endif

    static func selectionChanged() {
#if canImport(UIKit)
        Task {
            await MainActor.run {
                selectionFeedback.prepare()
                selectionFeedback.selectionChanged()
            }
        }
#endif
    }

}
