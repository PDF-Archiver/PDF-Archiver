//
//  AlertDataModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import SwiftUI

public struct AlertDataModel: Identifiable {
    public let id = UUID()
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
}

//extension AlertDataModel {
//
//    public enum ButtonType {
//        /// Creates an `Alert.Button` with the default style.
//        case `default`(_ label: Text, action: (() -> Void)? = {})
//
////        /// Creates an `Alert.Button` that indicates cancellation of some
////        /// operation.
////        case cancel(_ label: Text, action: (() -> Void)? = {})
//
//        /// An alert button that indicates cancellation.
//        ///
//        /// The system automatically chooses the label of the button for the
//        /// appropriate locale.
//        case cancel(_ action: (() -> Void)? = {})
//
//        /// Creates an `Alert.Button` with a style indicating destruction of
//        /// some data.
//        case destructive(_ label: Text, action: (() -> Void)? = {})
//
//        func createButton(completion: @escaping () -> Void) -> Alert.Button {
//            switch self {
//                case .default(let label, action: let action):
//                    return .default(label, action: {
//                        completion()
//                        action?()
//                    })
//                case .cancel(let action):
//                    return .cancel({
//                        completion()
//                        action?()
//                    })
//                case .destructive(let label, action: let action):
//                    return .destructive(label, action: {
//                        completion()
//                        action?()
//                    })
//            }
//        }
//    }
//
//
//}
