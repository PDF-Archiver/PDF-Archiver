//
//  IAPView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.05.24.
//

import OSLog
import StoreKit
import SwiftUI

struct IAPView: View {
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text("No Subscription")
                        .font(.title)
                    Text("Could not find a subscription or lifetime purchase. Please choose one of the options below to support the app development.")
                }

                features
                ProductView(id: "LIFETIME")
                    .productViewStyle(.large)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.paDarkRed, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(["SUBSCRIPTION_YEARLY_IOS_NEW", "SUBSCRIPTION_MONTHLY_IOS"], id: \.self) { id in
                        ProductView(id: id)
                            .productViewStyle(.compact)
                    }
                    HStack {
                        Spacer()
                        Text("You get a 2-week free trail before all subscriptions.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Spacer()
                    }
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.paDarkGray.opacity(0.125), lineWidth: 2)
                )

                HStack {
                    Spacer()
                    restore
                    Spacer()
                    cancel
                    Spacer()
                }
            }
            .padding()
        }

        .frame(minWidth: 400, idealWidth: 500)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden)
        .foregroundStyle(Color.paDarkGray)
        .background(Color.paBackground)
    }

    private var features: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Search PDFs", systemImage: "magnifyingglass")
                    Label("iCloud Sync", systemImage: "cloud")
                    Label("Open Source", systemImage: "lock.open")
                }
                .frame(maxWidth: 220, alignment: .leading)
                .padding()
                .background(Color.paDarkGray.opacity(0.125))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 6) {
                    Label("Scanner", systemImage: "doc.text.viewfinder")
                    Label("Searchable PDFs", systemImage: "doc.text.magnifyingglass")
                    Label("Tag PDFs", systemImage: "tag")
                }
                .frame(maxWidth: 220, alignment: .leading)
                .padding()
                .background(Color.paDarkGray.opacity(0.125))
                .cornerRadius(8)
                .overlay(alignment: .topTrailing) {
                    Text("Premium")
                        .padding(4)
                        .font(.footnote)
                        .foregroundColor(.paWhite)
                        .background(Color.paDarkRed)
                        .cornerRadius(8)
                        .transition(.scale)
                        .offset(x: -16, y: -12)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.paDarkRed)
                Text("Support further development of a 1 person team.")
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 250)
            }
            .padding()
            .background(Color.paDarkGray.opacity(0.125))
            .cornerRadius(8)
        }
    }

    private var restore: some View {
        Button {
            Task {
                do {
                    try await AppStore.sync()
                } catch {
                    Logger.inAppPurchase.errorAndAssert("AppStore sync failed: \(error)")
                }
            }
        } label: {
            Text("Restore purchases")
        }
        .buttonBorderShape(.capsule)
    }

    private var cancel: some View {
        Button {
            onCancel()
        } label: {
            Text("Cancel")
        }
        .buttonBorderShape(.capsule)
    }
}

#if DEBUG
#Preview("IAP light", traits: .fixedLayout(width: 400, height: 500)) {
    IAPView(onCancel: { print("Cancel pressed") })
        .preferredColorScheme(.light)
}

#Preview("IAP dark", traits: .fixedLayout(width: 400, height: 500)) {
    IAPView(onCancel: { print("Cancel pressed") })
        .preferredColorScheme(.dark)
}
#endif
