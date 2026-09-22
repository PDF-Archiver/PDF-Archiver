//
//  AboutPane.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.09.26.
//

#if os(macOS)
import ComposableArchitecture
import Shared
import StoreKit
import SwiftUI

struct AboutPane: View {
    @Bindable var store: StoreOf<Settings>

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    AboutMeView()
                } label: {
                    Label(String(localized: "About", bundle: #bundle), systemImage: "info.circle")
                }
            }

            Section {
                Button {
                    store.send(.onContactSupportTapped)
                } label: {
                    HStack {
                        Label(String(localized: "Contact & Help", bundle: #bundle), systemImage: "envelope")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    requestReview()
                } label: {
                    HStack {
                        Label(String(localized: "Rate App", bundle: #bundle), systemImage: "app.gift.fill")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ShareLink(item: store.appStoreUrl) {
                    HStack {
                        Label(String(localized: "Share App", bundle: #bundle), systemImage: "square.and.arrow.up")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Support", bundle: #bundle)
            }

            Section {
                LegalView(store: store)
            } header: {
                Text("Legal", bundle: #bundle)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview("AboutPane", traits: .fixedLayout(width: 500, height: 400)) {
    AboutPane(
        store: Store(initialState: Settings.State()) {
            Settings()
        }
    )
}
#endif
