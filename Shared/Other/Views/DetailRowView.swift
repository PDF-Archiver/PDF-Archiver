//
//  DetailRowView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct DetailRowView: View {
    let name: LocalizedStringKey
    let action: () -> Void
    var body: some View {
        Button {
            self.action()
        } label: {
            HStack {
                Text(name)
//                Spacer()
//                Image(systemName: "chevron.right")
//                    .foregroundColor(Color(.quaternaryLabel))
//                    .font(.system(.headline))
            }.accentColor(.primary)
        }
    }
}
