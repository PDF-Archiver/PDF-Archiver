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
        var showManageSubscription = false
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
        Reduce { state, action in
            switch action {
            case .showManageSubscription:
                #if os(iOS)
                state.showManageSubscription = true
                return .none
                #else
                return .run { _ in
                    let url = URL(string: "https://apps.apple.com/account/subscriptions")!
                    await openURL(url)
                }
                #endif
                
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
//            Link(destination: Self.manageSubscriptionUrl) {
//                Label(String(localized: "Manage Subscription", bundle: .module), systemImage: "switch.2")
//            }
        } header: {
            Text("Premium", bundle: .module)
                .foregroundStyle(Color.secondary)
        }
        #if os(macOS)
        .frame(width: 450, height: 50)
        #else
        .manageSubscriptionsSheet(isPresented: $store.showManageSubscription)
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
