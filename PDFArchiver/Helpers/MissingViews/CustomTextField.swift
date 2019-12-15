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

        var didBecomeFirstResponder = false
        let customTextField: CustomTextField

        init(customTextField: CustomTextField) {
            self.customTextField = customTextField
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            customTextField.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.autocorrectionType = .no
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let text = textField.text {
                customTextField.onCommit(text)
            }
            return true
        }

        @objc
        func tappedButton(sender: UIBarButtonItem) {
            guard let title = sender.title else { return }
            customTextField.onCommit(title)
        }
    }

    @Binding var text: String
    var placeholder: String
    var onCommit: (String) -> Void
    var isFirstResponder: Bool = false
    var suggestions: [String]

    func makeUIView(context: UIViewRepresentableContext<CustomTextField>) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = NSLocalizedString(placeholder, comment: "")
        return textField
    }

    func makeCoordinator() -> CustomTextField.Coordinator {
        return Coordinator(customTextField: self)
    }

    func updateUIView(_ uiView: UITextField, context: UIViewRepresentableContext<CustomTextField>) {

        // update textfield
        uiView.text = text
        if isFirstResponder && !context.coordinator.didBecomeFirstResponder {
            uiView.becomeFirstResponder()
            context.coordinator.didBecomeFirstResponder = true
        }

        // update input view
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: uiView.frame.width, height: 44))
        toolBar.tintColor = .paDarkGray
        var items = [UIBarButtonItem]()
        for suggestion in suggestions {
            items += [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                      UIBarButtonItem(title: suggestion, style: .plain, target: context.coordinator, action: #selector(Coordinator.tappedButton(sender:)))]
        }
        items += [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)]

        toolBar.items = items
        uiView.inputAccessoryView = toolBar
        uiView.reloadInputViews()
    }
}
