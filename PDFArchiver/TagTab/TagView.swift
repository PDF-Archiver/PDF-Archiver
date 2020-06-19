//
//  TagView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct TagView: View {

    let tagName: String
    let isEditable: Bool
    let tapHandler: ((String) -> Void)?

    var body: some View {
        Button(action: {
            self.tapHandler?(self.tagName)
        }, label: {
            self.tag
        })
    }

    private var tag: some View {
        HStack {
            Image(systemName: "tag")
            Text(self.tagName)
                .lineLimit(1)
            if self.isEditable {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .padding(EdgeInsets(top: 2.0, leading: 5.0, bottom: 2.0, trailing: 5.0))
        .foregroundColor(.white)
        .background(Color(.paLightRed))
        .cornerRadius(8.0)
        .transition(.opacity)
        .animation(.spring())
    }
}
