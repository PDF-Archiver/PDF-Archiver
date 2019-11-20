//
//  CustomTextField.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct CustomTextField: UIViewRepresentable {

    class Coordinator: NSObject, UITextFieldDelegate {

        @Binding var text: String
        var suggestionView: UIView
        var onCommit: (UITextField) -> Void
        var didBecomeFirstResponder = false

        init(text: Binding<String>, suggestionView: UIView, onCommit: @escaping (UITextField) -> Void) {
            _text = text
            self.suggestionView = suggestionView
            self.onCommit = onCommit
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.autocorrectionType = .no
            textField.inputAccessoryView = suggestionView
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onCommit(textField)
            return true
        }
    }

    @Binding var text: String
    var placeholder: String
    var suggestionView: UIView
    var onCommit: (UITextField) -> Void
    var isFirstResponder: Bool = false

    func makeUIView(context: UIViewRepresentableContext<CustomTextField>) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        return textField
    }

    func makeCoordinator() -> CustomTextField.Coordinator {
        return Coordinator(text: $text,
                           suggestionView: suggestionView,
                           onCommit: onCommit)
    }

    func updateUIView(_ uiView: UITextField, context: UIViewRepresentableContext<CustomTextField>) {
        uiView.text = text
        if isFirstResponder && !context.coordinator.didBecomeFirstResponder {
            uiView.becomeFirstResponder()
            context.coordinator.didBecomeFirstResponder = true
        }
    }
}
