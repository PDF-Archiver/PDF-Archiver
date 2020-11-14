//
//  InputAccessoryView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 08.07.20.
//

import SwiftUI

struct InputAccessoryView: View {

    let items: [String]
    let callback: (String) -> Void

    var body: some View {
        HStack {
            ForEach(0..<items.count) { index in
                let item = items[index]
                Button(item) {
                    callback(item)
                }
                if index != (items.count - 1) {
                    Divider()
                        .backgroundFill(.systemGray6)
                        .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, idealHeight: 44)
    }
}

struct InputAccessoryView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            InputAccessoryView(items: ["Tag1", "Tag2", "Tag3"]) { item in
                print("Selected: \(item)")
            }
            .frame(height: 100)
            Spacer()
        }
        .previewLayout(.sizeThatFits)
    }
}
