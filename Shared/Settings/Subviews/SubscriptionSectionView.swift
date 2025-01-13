//
//  SubscriptionSectionView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.06.24.
//

import SwiftUI

struct SubscriptionSectionView: View {
    private static let manageSubscriptionUrl = URL(string: "https://apps.apple.com/account/subscriptions")!

    @Environment(NavigationModel.self) var navigationModel

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

            Link("Manage Subscription", destination: Self.manageSubscriptionUrl)
        } header: {
            Text("⭐️ Premium")
        }
        #if os(macOS)
        .frame(width: 450, height: 50)
        #endif
    }
}

#if DEBUG
#Preview {
    SubscriptionSectionView()
        .environment(NavigationModel.shared)
}
#endif
