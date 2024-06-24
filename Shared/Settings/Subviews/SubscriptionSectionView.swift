//
//  SubscriptionSectionView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.06.24.
//

import SwiftUI

struct SubscriptionSectionView: View {
    private static let manageSubscriptionUrl = URL(string: "https://apps.apple.com/account/subscriptions")!

    @Environment(Subscription.self) var subscription

    var body: some View {
        Section {
            HStack {
                Text("Status:")
                Text(subscription.isSubscribed.wrappedValue ? "Active ✅" : "Inactive ❌")
            }

            DetailRowView(name: "Activate/Restore Premium") {
#warning("TODO: implement this")
                //                NotificationCenter.default.post(.showSubscriptionView)
            }

            Link("Manage Subscription", destination: Self.manageSubscriptionUrl)
        } header: {
            Text("⭐️ Premium")
        }
    }
}

#if DEBUG
#Preview {
    SubscriptionSectionView()
        .environment(Subscription())
}
#endif
