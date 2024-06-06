//
//  InAppPurchaseView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.05.24.
//

import StoreKit
import SwiftUI

struct InAppPurchaseView: View {
    let onCancel: () -> Void
    
    @State private var chooseSubscription = false

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                VStack(spacing: 10) {
                    Text("No Subscription")
                        .font(.title)
                    Text("Could not find a subscription or lifetime purchase. Please choose one of the options below to support the app development.")
                }
                
                features
                ProductView(id: "LIFETIME")
                    .productViewStyle(.large)
                
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(["SUBSCRIPTION_YEARLY_IOS_NEW", "SUBSCRIPTION_MONTHLY_IOS"], id: \.self) { id in
                        ProductView(id: id)
                            .productViewStyle(.compact)
                    }
                }
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
        VStack(alignment: .center, spacing: 8) {
            WidthSyncedRow(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Search PDFs" as LocalizedStringKey, systemImage: "magnifyingglass")
                    Label("iCloud Sync" as LocalizedStringKey, systemImage: "cloud")
                    Label("Open Source" as LocalizedStringKey, systemImage: "lock.open")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.paDarkGray.opacity(0.125))
                .cornerRadius(8)
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Scanner" as LocalizedStringKey, systemImage: "doc.text.viewfinder")
                        Label("Searchable PDFs" as LocalizedStringKey, systemImage: "doc.text.magnifyingglass")
                        Label("Tag PDFs" as LocalizedStringKey, systemImage: "tag")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.paDarkGray.opacity(0.125))
                    .cornerRadius(8)
                    ZStack {
                        Text("Premium")
                            .padding(4)
                            .font(.footnote)
                            .foregroundColor(.paWhite)
                            .background(Color.paDarkRed)
                            .cornerRadius(8)
                            .transition(.scale)
                    }
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
                    print(error)
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
    InAppPurchaseView(onCancel: { print("Cancel pressed") })
        .preferredColorScheme(.light)
}

#Preview("IAP dark", traits: .fixedLayout(width: 400, height: 500)) {
    InAppPurchaseView(onCancel: { print("Cancel pressed") })
        .preferredColorScheme(.dark)
}
#endif
