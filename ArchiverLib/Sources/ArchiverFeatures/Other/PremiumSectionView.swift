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

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .showManageSubscription:
                return .run { _ in
                    let url = URL(string: "https://apps.apple.com/account/subscriptions")!
                    await openURL(url)
                }

            case .binding, .delegate:
                return .none
            }
        }
    }
}

 struct PremiumSectionView: View {
//    // swiftlint:disable:next force_unwrapping
//    private static let manageSubscriptionUrl = URL(
//        string: "https://apps.apple.com/account/subscriptions")!

     @Bindable var store: StoreOf<PremiumSection>

    var body: some View {
        Section {
            #if os(macOS)
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
            #else
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
            #endif
            if store.premiumStatus == .inactive {
                Button {
                    store.send(.delegate(.switchToInboxTab))
                } label: {
                    #if os(macOS)
                    HStack {
                        Label(String(localized: "Activate premium", bundle: .module), systemImage: "cart")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    #else
                    Label(String(localized: "Activate premium", bundle: .module), systemImage: "cart")
                    #endif
                }
                #if os(macOS)
                .buttonStyle(.plain)
                #endif
            }

            Button {
                store.send(.showManageSubscription)
            } label: {
                #if os(macOS)
                HStack {
                    Label(String(localized: "Manage Subscription", bundle: .module), systemImage: "switch.2")
                    Spacer()
                }
                .contentShape(Rectangle())
                #else
                Label(String(localized: "Manage Subscription", bundle: .module), systemImage: "switch.2")
                #endif
            }
            #if os(macOS)
            .buttonStyle(.plain)
            #endif
        } header: {
            Text("Premium", bundle: .module)
                .foregroundStyle(Color.secondary)
        }
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
