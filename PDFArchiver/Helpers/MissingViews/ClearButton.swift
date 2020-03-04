//
//  ClearingTextField.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct ClearButton: ViewModifier {
    @Binding var text: String

    func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
            // onTapGesture is better than a Button here when adding to a form
            Image(systemName: "multiply.circle.fill")
                .foregroundColor(.secondary)
                .opacity(text.isEmpty ? 0 : 1)
                .onTapGesture { self.text = "" }
        }
    }
}

struct ClearingTextField_Previews: PreviewProvider {
    @State static var text = "Test"
    static var previews: some View {
        TextField("Placeholder", text: $text)
            .modifier(ClearButton(text: $text))
    }
}
