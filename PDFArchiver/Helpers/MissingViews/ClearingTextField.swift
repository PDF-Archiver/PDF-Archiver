//
//  ClearingTextField.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct ClearingTextField: View {

    var placeholder: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
            Button(action: {
                self.text = ""
            }, label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.secondary)
                    .opacity(self.text.isEmpty ? 0.0 : 1.0)
            })
        }
    }
}

struct ClearingTextField_Previews: PreviewProvider {
    static var previews: some View {
        ClearingTextField(placeholder: "Placeholder", text: .constant("Test"))
    }
}
