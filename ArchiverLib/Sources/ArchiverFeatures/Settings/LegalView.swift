//
//  LegalView.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 09.10.25.
//

import ComposableArchitecture
import Shared
import SwiftUI

struct LegalView: View {
    @Bindable var store: StoreOf<Settings>

    var body: some View {
            Group {
                NavigationLink {
                    MarkdownView(markdown: String(localized: "TERMS_OF_USE", bundle: #bundle))
                        .navigationTitle(String(localized: "Terms of Use", bundle: #bundle))
                } label: {
                    Label(String(localized: "Terms of Use", bundle: #bundle), systemImage: "doc.text")
                }

                NavigationLink {
                    MarkdownView(markdown: String(localized: "PRIVACY", bundle: #bundle))
                        .navigationTitle(String(localized: "Privacy", bundle: #bundle))
                } label: {
                    Label(String(localized: "Privacy", bundle: #bundle), systemImage: "hand.raised")
                }

                NavigationLink {
                    MarkdownView(markdown: String(localized: "IMPRINT", bundle: #bundle))
                        .navigationTitle(Text("Imprint", bundle: #bundle))
                } label: {
                    Label(String(localized: "Imprint", bundle: #bundle), systemImage: "envelope.front")
                }

                Button {
                    store.send(.onOpenPdfArchiverWebsiteTapped)
                } label: {
                    HStack {
                        Label(String(localized: "PDF Archiver Website", bundle: #bundle), systemImage: "globe")
                        #if os(iOS)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        #endif
                    }
                }
                #if os(macOS)
                .buttonStyle(.link)
                #endif
            }
            .foregroundColor(.primary)
    }
}

#Preview("Legal", traits: .fixedLayout(width: 500, height: 400)) {
    LegalView(
        store: Store(initialState: Settings.State()) {
            Settings()
                ._printChanges()
        }
    )
}
