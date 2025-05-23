//
//  MarkdownView.swift
//  
//
//  Created by Julian Kahnert on 28.11.20.
//

import Parma
import SwiftUI

struct MarkdownView: View {
    var title: LocalizedStringKey
    var markdown: String
    let scrollView: Bool
    var body: some View {
        if !scrollView {
            Parma(markdown)
                .navigationTitle(title)
        } else {
            NavigationLink {
                ScrollView {
                    Parma(markdown)
                }
                .padding(.horizontal, 16)
                .navigationTitle(title)
            } label: {
                Text(title)
            }
        }
    }
}

#Preview {
    MarkdownView(title: "Markdown View", markdown: """
        # Title
        This is a test list:
        * item 1
        * item 2
        * item 3
        """, scrollView: true)
}
