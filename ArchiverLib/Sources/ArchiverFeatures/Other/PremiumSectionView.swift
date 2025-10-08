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
        case delegate(Delegate)

        enum Delegate: Equatable {
          case switchToInboxTab
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { _, action in
            switch action {
            case .binding, .delegate:
                return .none
            }
        }
    }
}

 struct PremiumSectionView: View {
    // swiftlint:disable:next force_unwrapping
    private static let manageSubscriptionUrl = URL(
        string: "https://apps.apple.com/account/subscriptions")!

     @Bindable var store: StoreOf<PremiumSection>

    var body: some View {
        Section {
            HStack {
                Text("Premium Status:", bundle: .module)
                switch store.premiumStatus {
                case .loading:
                    ProgressView()
                case .active:
                    Text("Active ✅", bundle: .module)
                case .inactive:
                    Text("Inactive ❌", bundle: .module)
                }
            }
            if store.premiumStatus == .inactive {
                Button {
                    store.send(.delegate(.switchToInboxTab))
                } label: {
                    Text("Activate premium", bundle: .module)
                }
            }

            Link(String(localized: "Manage Subscription", bundle: .module), destination: Self.manageSubscriptionUrl)
        } header: {
            Text("⭐️ Premium")
        }
        #if os(macOS)
        .frame(width: 450, height: 50)
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
