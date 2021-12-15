//
//  MoreTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveBackend
import SwiftUI
import SwiftUIX

#if !os(macOS)
struct MoreTabView: View {

    @ObservedObject var viewModel: MoreTabViewModel

    var body: some View {
        Form {
            preferences
            subscription
            statistics
            moreInformation
        }
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
            Button("Open Archive Folder (☁️ iCloud Drive)" as LocalizedStringKey, action: viewModel.openArchiveFolder)
                // if statement in view not possible, because the StorageSelectionView was not returning to the overview
                // after the selection has changed.
                .disabled(PathManager.shared.archivePathType != .iCloudDrive)
                .opacity(PathManager.shared.archivePathType == .iCloudDrive ? 1 : 0.3)
            DetailRowView(name: "Show Intro") {
                self.viewModel.showIntro()
            }
            NavigationLink(destination: ExpertSettingsView(notSaveDocumentTagsAsPDFMetadata: $viewModel.notSaveDocumentTagsAsPDFMetadata,
                                                           documentTagsNotRequired: $viewModel.documentTagsNotRequired,
                                                           documentSpecificationNotRequired: $viewModel.documentSpecificationNotRequired,
                                                           showPermissions: viewModel.showPermissions,
                                                           resetApp: viewModel.resetApp)) {
                Text("Advanced")
            }
        }
    }

    private var subscription: some View {
        Section(header: Text("⭐️ Premium")) {
            HStack {
                Text("Status:")
                Text(viewModel.subscriptionStatus)
            }

            DetailRowView(name: "Activate/Restore Premium") {
                NotificationCenter.default.post(.showSubscriptionView)
            }
            Link("Manage Subscription", destination: viewModel.manageSubscriptionUrl)
        }
    }

    private var statistics: some View {
        Section(header: Text("🧾 Statistics")) {
            StatisticsView(viewModel: viewModel.statisticsViewModel)
        }
    }

    private var moreInformation: some View {
        Section(header: Text("⁉️ More Information"), footer: Text("Version \(MoreTabViewModel.appVersion)")) {
            NavigationLink(destination: AboutMeView()) {
                Text("About  👤")
            }
            Link("PDF Archiver Website  🖥", destination: viewModel.pdfArchiverUrl)
            MoreTabViewModel.markdownView(for: "Terms & Privacy", withKey: "Privacy")
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
