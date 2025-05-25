//
//  PremiumSectionView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.06.24.
//

import SwiftUI

struct PremiumSectionView: View {
    private static let manageSubscriptionUrl = URL(string: "https://apps.apple.com/account/subscriptions")!

    @Environment(NavigationModel.self) var navigationModel
    @State private var showIapView: Bool = false

    var body: some View {
        Section {
            HStack {
                Text("Premium Status:")
                switch navigationModel.premiumStatus {
                case .loading:
                    ProgressView("Loading ...")
                case .active:
                    Text("Active ✅")
                case .inactive:
                    Text("Inactive ❌")
                }
            }
            if !navigationModel.isSubscribedOrLoading.wrappedValue {
                Button {
                    showIapView = true
                } label: {
                    Text("Activate premium")
                }
                #if os(macOS)
                .sheet(isPresented: $showIapView) {
                    IAPView {
                        showIapView = false
                    }
                }
                #else
                .navigationDestination(isPresented: $showIapView) {
                    IAPView {
                        showIapView = false
                    }
                }
                #endif
            }

            Link("Manage Subscription", destination: Self.manageSubscriptionUrl)
        } header: {
            Text("⭐️ Premium")
        }
        #if os(macOS)
        .frame(width: 450, height: 50)
        #endif
        .onChange(of: navigationModel.premiumStatus) { _, newValue in
            guard showIapView && newValue == .active else { return }
            showIapView = false
        }
    }
}

#if DEBUG
#Preview {
    PremiumSectionView()
        .environment(NavigationModel.shared)
}
#endif
