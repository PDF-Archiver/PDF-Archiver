//
//  MoreTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import SwiftUIX
import Parma

#if os(macOS)
private typealias CustomListStyle = InsetListStyle
private typealias CustomNavigationtStyle = DefaultNavigationViewStyle
#else
private typealias CustomListStyle = GroupedListStyle
private typealias CustomNavigationtStyle = StackNavigationViewStyle
#endif

struct MoreTabView: View {

    @ObservedObject var viewModel: MoreTabViewModel
    private static let appVersion = AppEnvironment.getFullVersion()

    var body: some View {
        Form {
            preferences
            subscription
            moreInformation
        }
        .listStyle(CustomListStyle())
        .foregroundColor(.primary)
        .navigationTitle("Preferences & More")
        .navigationViewStyle(CustomNavigationtStyle())
        .emittingError(viewModel.error)
    }

    private var preferences: some View {
        Section(header: Text("🛠 Preferences")) {
            Picker(selection: $viewModel.selectedQualityIndex, label: Text("PDF Quality")) {
                ForEach(0..<viewModel.qualities.count, id: \.self) {
                    Text(self.viewModel.qualities[$0])
                }
            }
            NavigationLink(destination: StorageSelectionView(selection: $viewModel.selectedArchiveType), isActive: $viewModel.showArchiveTypeSelection) {
                HStack {
                    Text("Storage")
                    Spacer()
                    Text(viewModel.selectedArchiveType.title)
                }
            }
            DetailRowView(name: "Show Intro") {
                self.viewModel.showIntro()
            }
            DetailRowView(name: "Show Permissions") {
                self.viewModel.showPermissions()
            }
            DetailRowView(name: "Reset App Preferences") {
                self.viewModel.resetApp()
            }
        }
    }

    private var subscription: some View {
        Section(header: Text("🧾 Subscription")) {
            HStack {
                Text("Status:")
                Text(viewModel.subscriptionStatus)
            }

            DetailRowView(name: "Activate/Restore Subscription") {
                NotificationCenter.default.post(.showSubscriptionView)
            }
            Link("Manage Subscription", destination: viewModel.manageSubscriptionUrl)
        }
    }

    private var moreInformation: some View {
        Section(header: Text("⁉️ More Information"), footer: Text("Version \(MoreTabView.appVersion)")) {
            NavigationLink(destination: AboutMeView()) {
                Text("About  👤")
            }
            Link("PDF Archiver (macOS)  🖥", destination: viewModel.macOSAppUrl)
            markdownView(for: "Terms of Use & Privacy Policy", withKey: "Privacy")
            markdownView(for: "Imprint", withKey: "Imprint")
            DetailRowView(name: "Contact Support  🚑") {
                NotificationCenter.default.post(Notification(name: .showSendDiagnosticsReport))
            }
        }
    }

    private func markdownView(for title: LocalizedStringKey, withKey key: String) -> some View {
        guard let url = Bundle.main.url(forResource: key, withExtension: "md"),
              let markdown = try? String(contentsOf: url) else { preconditionFailure("Could not fetch file \(key)") }

        return NavigationLink {
            LazyView {
                ScrollView {
                    Parma(markdown)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle(title)
        } label: {
            Text(title)
        }
    }
}

#if DEBUG
import Combine
import StoreKit
import InAppPurchases
struct MoreTabView_Previews: PreviewProvider {
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

    private class MockArchiveStoreAPI: ArchiveStoreAPI {
        func update(archiveFolder: URL, untaggedFolders: [URL]) {}
        func archive(_ document: Document, slugify: Bool) throws {}
        func download(_ document: Document) throws {}
        func delete(_ document: Document) throws {}
        func getCreationDate(of url: URL) throws -> Date? { nil }
    }

    @State static var viewModel = MoreTabViewModel(iapService: MockIAPService(), archiveStore: MockArchiveStoreAPI())
    static var previews: some View {
        Group {
            MoreTabView(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .padding()
        }
    }
}
#endif
