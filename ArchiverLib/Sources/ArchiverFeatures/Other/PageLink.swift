//
//  PageLink.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 18.10.26.
//

import Shared
import SwiftUI

/// Opens a secondary page: pushed on iOS, as a sheet on macOS.
///
/// The Mac Settings window centers its toolbar items, so a pushed page's back button would sit under the title.
struct PageLink<LabelContent: View, Destination: View>: View {
    @ViewBuilder var destination: () -> Destination
    @ViewBuilder var label: () -> LabelContent

    #if os(macOS)
    @State private var isPresented = false
    #endif

    var body: some View {
        #if os(macOS)
        Button {
            isPresented = true
        } label: {
            HStack {
                label()
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Rows in a settings form; a focus ring would frame the whole row.
        .focusable(false)
        .sheet(isPresented: $isPresented) {
            PageSheet(onDone: { isPresented = false }, content: destination)
        }
        #else
        NavigationLink(destination: destination, label: label)
        #endif
    }
}

/// A read-only page in a sheet, closed with the OK button.
struct PageSheet<Content: View>: View {
    let onDone: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Spacer()
                okButton
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 520, height: 560)
        #else
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        okButton
                    }
                }
        }
        #endif
    }

    private var okButton: some View {
        Button {
            onDone()
        } label: {
            Text("OK", bundle: #bundle)
        }
    }
}

#Preview("PageSheet") {
    PageSheet(onDone: {}, content: {
        MarkdownView(markdown: String(localized: "IMPRINT", bundle: #bundle))
    })
}
