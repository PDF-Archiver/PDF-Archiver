//
//  MarkdownView.swift
//  
//
//  Created by Julian Kahnert on 28.11.20.
//

import Parma
import SwiftUI
import SwiftUIX

struct MarkdownView: View {
    var title: LocalizedStringKey
    var markdown: String
    var body: some View {
        NavigationLink {
            LazyView {
                ScrollView {
                    Parma(markdown)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle(title)
        } label: {
            Text(title)
        }
    }
}

struct MarkdownView_Previews: PreviewProvider {
    static var previews: some View {
        MarkdownView(title: "Markdown View", markdown: """
        # Title
        This is a test list:
        * item 1
        * item 2
        * item 3
        """)
    }
}
