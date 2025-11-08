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
        @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .inactive
        var showIapView = false
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
                // swiftlint:disable:next force_unwrapping
                let url = URL(string: "https://apps.apple.com/account/subscriptions")!
                #if os(iOS)
                return .run { _ in
                    await openURL(url)
                }
                #else
                #if DEBUG
                return .run { _ in
                    await openURL(url)
                }
                #else
                NSWorkspace.shared.open(url)
                return .none
                #endif
                #endif

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
            Group {
                switch store.premiumStatus {
                case .loading:
                    ProgressView()
                case .active:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Active", bundle: .module)
                    }
                    .font(.largeTitle)
                case .inactive:
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Inactive", bundle: .module)
                    }
                    .font(.largeTitle)
                }
            }
            .padding()

            if store.premiumStatus == .inactive {
                Button {
                    store.send(.delegate(.switchToInboxTab))
                } label: {
                    HStack {
                        Label(String(localized: "Activate premium", bundle: .module), systemImage: "cart")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }

            Button {
                store.send(.showManageSubscription)
            } label: {
                HStack {
                    Label(String(localized: "Manage Subscription", bundle: .module), systemImage: "switch.2")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 300)
        #else
        Section {
            HStack {
                Label(String(localized: "Premium Status", bundle: .module), systemImage: "star")
                Spacer()
                switch store.premiumStatus {
                case .loading:
                    ProgressView()
                case .active:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Active", bundle: .module)
                    }
                case .inactive:
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Inactive", bundle: .module)
                    }
                }
            }

            if store.premiumStatus == .inactive {
                Button {
                    store.send(.delegate(.switchToInboxTab))
                } label: {
                    Label(String(localized: "Activate premium", bundle: .module), systemImage: "cart")
                }
            }

            Button {
                store.send(.showManageSubscription)
            } label: {
                Label(String(localized: "Manage Subscription", bundle: .module), systemImage: "switch.2")
            }
        } header: {
            Text("Premium", bundle: .module)
                .foregroundStyle(Color.secondary)
        }
        #endif
    }
 }

#if DEBUG
#Preview("PremiumSectionView") {
    PremiumSectionView(
        store: Store(initialState: PremiumSection.State()) {
            PremiumSection()
                ._printChanges()
        }
    )
}
#endif
