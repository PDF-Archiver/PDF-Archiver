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
        Form {
            Section {
                NavigationLink {
                    MarkdownView(markdown: String(localized: "TERMS_OF_USE", bundle: .module))
                        .navigationTitle(String(localized: "Terms of Use", bundle: .module))
                } label: {
                    Label(String(localized: "Terms of Use", bundle: .module), systemImage: "doc.text")
                }

                NavigationLink {
                    MarkdownView(markdown: String(localized: "PRIVACY", bundle: .module))
                        .navigationTitle(String(localized: "Privacy", bundle: .module))
                } label: {
                    Label(String(localized: "Privacy", bundle: .module), systemImage: "hand.raised")
                }

                NavigationLink {
                    MarkdownView(markdown: String(localized: "IMPRINT", bundle: .module))
                        .navigationTitle(Text("Imprint", bundle: .module))
                } label: {
                    Label(String(localized: "Imprint", bundle: .module), systemImage: "envelope.front")
                }

                Button {
                    store.send(.onOpenPdfArchiverWebsiteTapped)
                } label: {
                    HStack {
                        Label(String(localized: "PDF Archiver Website", bundle: .module), systemImage: "globe")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .foregroundColor(.primary)
        }
    }
}
