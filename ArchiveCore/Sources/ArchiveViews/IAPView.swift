//
//  IAPView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import SwiftUIX

struct IAPView: View {
    #if os(macOS)
    private static let maxHeight: CGFloat? = 600
    #else
    private static let maxHeight: CGFloat? = nil
    #endif

    @ObservedObject var viewModel: IAPViewModel
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        LazyView {
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                title
                features
                subscriptionButtons
                text
                otherButtons
                Spacer()
            }
            .padding()
            .frame(maxWidth: 600, maxHeight: Self.maxHeight)
            .onAppear {
                #if !os(macOS)
                Keyboard.main.dismiss()
                #endif
            }
        }
    }

    private var title: some View {
        HStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .frame(width: 75.0, height: 75.0, alignment: .center)
            VStack(alignment: .leading) {
                Text("PDF Archiver")
                    .font(.subheadline)
                Text("Premium Subscription")
                    .font(.title)
            }
            .foregroundColor(.paDarkGray)
        }.padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 16))
    }

    private var features: some View {
        VStack(alignment: .center, spacing: 8) {
            WidthSyncedRow(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Search PDFs" as LocalizedStringKey, systemImage: .magnifyingglass)
                    Label("iCloud Sync" as LocalizedStringKey, systemImage: .cloud)
                    Label("Open Source" as LocalizedStringKey, systemImage: .lockOpen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.paDarkGray.opacity(0.125))
                .cornerRadius(8)
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Scanner" as LocalizedStringKey, systemImage: .docTextViewfinder)
                        Label("Searchable PDFs" as LocalizedStringKey, systemImage: .docTextMagnifyingglass)
                        Label("Tag PDFs" as LocalizedStringKey, systemImage: .tag)
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
                            .background(.paDarkRed)
                            .cornerRadius(8)
                            .animation(nil)
                            .transition(.scale)
                    }
                    .offset(x: -16, y: -12)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: .heartFill)
                    .foregroundColor(.paDarkRed)
                Text("Support further development of a 1 person team.")
                .fixedSize(horizontal: false, vertical: true)
                .maxWidth(250)
            }
            .padding()
            .background(Color.paDarkGray.opacity(0.125))
            .cornerRadius(8)
        }
    }

    private var subscriptionButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                self.viewModel.tapped(button: .level1, presentationMode: self.presentationMode)
            }, label: {
                VStack(spacing: 4) {
                    Text("Monthly")
                        .font(.headline)
                    Text(self.viewModel.level1Name)
                }
                .padding(.vertical, 4)
            })
            .buttonStyle(SubscriptionButtonStyle(isPreferred: false))

            Button(action: {
                self.viewModel.tapped(button: .level2, presentationMode: self.presentationMode)
            }, label: {
                VStack(spacing: 8) {
                    Text("Yearly")
                        .font(.headline)
                    Text(self.viewModel.level2Name)
                }
                .padding(.vertical, 4)
            })
            .buttonStyle(SubscriptionButtonStyle(isPreferred: true))
        }
    }

    private var text: some View {
        ScrollView {
            Text("• Try the app for free! You can try the app in a free trial period of 2 weeks by choosing a subscription. You can try the app without any costs in this period.\n• Your Apple account will be charged for the next subscription period within the final 24 hours of the current period.\n• The subscription will renew automatically if you do not deactivate the renewal in the account setting in iTunes or the App Store at least 24 hours before the end of the subscription period.")
                .font(.caption)
                .foregroundColor(.paLightGray)
        }
        .maxHeight(200)
    }

    private var otherButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                self.viewModel.tapped(button: .restore, presentationMode: self.presentationMode)
            }, label: {
                Text("Restore")
            })
            .buttonStyle(FilledButtonStyle(foregroundColor: .paDarkGray, backgroundColor: .systemBackground))

            Button(action: {
                self.viewModel.tapped(button: .cancel, presentationMode: self.presentationMode)

            }, label: {
                Text("Cancel")
            })
            .buttonStyle(FilledButtonStyle(foregroundColor: .paDarkRed, backgroundColor: .systemBackground))
        }
    }
}

#if DEBUG
import Combine
import StoreKit
struct IAPView_Previews: PreviewProvider {
    @State static var viewModel = IAPViewModel(iapService: MockIAPService())
    static var previews: some View {
        IAPView(viewModel: viewModel)
            //.previewDevice("Mac")
            .makeForPreviewProvider()
    }
}

extension IAPView_Previews {
    private class MockIAPService: IAPServiceAPI {
        var productsPublisher: AnyPublisher<Set<SKProduct>, Never> {
            Just([]).eraseToAnyPublisher()
        }
        var appUsagePermitted: Bool = true
        var appUsagePermittedPublisher: AnyPublisher<Bool, Never> {
            Just(appUsagePermitted).eraseToAnyPublisher()
        }
        func buy(subscription: IAPService.SubscriptionType) throws {}
        func restorePurchases() {}
    }
}
#endif
