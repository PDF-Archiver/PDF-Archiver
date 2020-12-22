//
//  MoreTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import SwiftUIX

#if !os(macOS)
struct MoreTabView: View {

    @ObservedObject var viewModel: MoreTabViewModel

    var body: some View {
        Form {
            preferences
            subscription
            moreInformation
        }
        .listStyle(GroupedListStyle())
        .foregroundColor(.primary)
        .navigationTitle("Preferences & More")
        .navigationViewStyle(StackNavigationViewStyle())
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
        Section(header: Text("⁉️ More Information"), footer: Text("Version \(MoreTabViewModel.appVersion)")) {
            NavigationLink(destination: AboutMeView()) {
                Text("About  👤")
            }
            Link("PDF Archiver (macOS)  🖥", destination: viewModel.macOSAppUrl)
            MoreTabViewModel.markdownView(for: "Terms of Use & Privacy Policy", withKey: "Privacy")
            MoreTabViewModel.markdownView(for: "Imprint", withKey: "Imprint")
            DetailRowView(name: "Contact Support  🚑") {
                NotificationCenter.default.post(Notification(name: .showSendDiagnosticsReport))
            }
        }
    }
}
#endif

#if DEBUG && !os(macOS)
struct MoreTabView_Previews: PreviewProvider {
    @State static var viewModel = MoreTabViewModel.previewViewModel
    static var previews: some View {
        Group {
            MoreTabView(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .padding()
        }
    }
}
#endif
