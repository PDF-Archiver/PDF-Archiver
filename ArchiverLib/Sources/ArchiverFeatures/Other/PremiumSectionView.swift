//
//  PremiumSectionView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.06.24.
//

import ArchiverModels
import ComposableArchitecture
import SwiftUI

@Reducer
struct PremiumSection {

    @ObservableState
    struct State: Equatable {
        @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .loading
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case showManageSubscription
        case delegate(Delegate)

        enum Delegate: Equatable {
          case switchToInboxTab
        }
    }

    @Dependency(\.openURL) var openURL

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { _, action in
            switch action {
            case .showManageSubscription:
                return .openExternalURL(URL(string: "https://apps.apple.com/account/subscriptions")!, with: openURL)

            case .binding, .delegate:
                return .none
            }
        }
    }
}

struct PremiumSectionView: View {
    @Bindable var store: StoreOf<PremiumSection>

    var body: some View {
        #if os(macOS)
        Section {
            SettingsRow(title: "Status") {
                statusLabel
            }

            SettingsRow(title: "Subscription") {
                HStack(spacing: 6) {
                    if store.premiumStatus == .inactive {
                        Button(String(localized: "Activate premium", bundle: #bundle)) {
                            store.send(.delegate(.switchToInboxTab))
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(String(localized: "Manage Subscription", bundle: #bundle)) {
                        store.send(.showManageSubscription)
                    }
                }
            }
        } footer: {
            // Below the grouped box rather than in a row: the banner draws its own card.
            ExchangeBannerSlot()
                // Same reason as in `ArchiveListView`: the SDK card only shrinks via scaling on the Mac.
                .scaleEffect(0.8, anchor: .top)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        #else
        Section {
            HStack {
                Label(String(localized: "Premium Status", bundle: #bundle), systemImage: "star")
                Spacer()
                switch store.premiumStatus {
                case .loading:
                    ProgressView()

                case .active:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Active", bundle: #bundle)
                    }

                case .inactive:
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Inactive", bundle: #bundle)
                    }
                }
            }

            if store.premiumStatus == .inactive {
                Button {
                    store.send(.delegate(.switchToInboxTab))
                } label: {
                    Label(String(localized: "Activate premium", bundle: #bundle), systemImage: "cart")
                }
            }

            Button {
                store.send(.showManageSubscription)
            } label: {
                Label(String(localized: "Manage Subscription", bundle: #bundle), systemImage: "switch.2")
            }
        } footer: {
            // Below the grouped box rather than in a row: the banner draws its own card.
            ExchangeBannerSlot()
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private var statusLabel: some View {
        switch store.premiumStatus {
        case .loading:
            ProgressView()
                .controlSize(.small)

        case .active:
            Label {
                Text("Active", bundle: #bundle)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

        case .inactive:
            Label {
                Text("Inactive", bundle: #bundle)
            } icon: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }
    #endif
 }

#if DEBUG
#Preview("PremiumSectionView", traits: .fixedLayout(width: 560, height: 360)) {
    @Shared(.premiumStatus) var premiumStatus = PremiumStatus.loading
    Form {
        PremiumSectionView(
            store: Store(initialState: PremiumSection.State()) {
                PremiumSection()
                    ._printChanges()
            }
        )
    }
    .formStyle(.grouped)
    .onAppear { $premiumStatus.withLock { $0 = .inactive } }
    .environment(\.exchangeBanner, AnyView(Text(verbatim: "Banner").padding().background(.background, in: .rect(cornerRadius: 12))))
}
#endif
