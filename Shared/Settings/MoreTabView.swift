//
//  SettingsView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

#if !os(macOS)
struct SettingsView: View {
//    private static let appId = 1433801905

    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showActivityView = false

    var body: some View {
        NavigationStack {
            Form {
                preferences
                SubscriptionSectionView()
                statistics
                moreInformation
            }
            .foregroundColor(.primary)
            .navigationTitle("Preferences & More")
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
//        .sheet(isPresented: $showActivityView) {
//            // swiftlint:disable:next force_unwrapping
//            AppActivityView(activityItems: [URL(string: "https://apps.apple.com/app/pdf-archiver/id\(Self.appId)")!])
//        }
    }

    @ViewBuilder
    private var preferences: some View {
        Section {
            Picker(selection: $viewModel.selectedQualityIndex, label: Text("PDF Quality")) {
                ForEach(0..<viewModel.qualities.count, id: \.self) {
                    Text(self.viewModel.qualities[$0])
                }
            }

            Button {
                viewModel.showArchiveTypeSelection = true
            } label: {
                HStack {
                    Text("Storage")
                    Spacer()
                    Text(viewModel.selectedArchiveType.title)
                }
            }
            .navigationDestination(isPresented: $viewModel.showArchiveTypeSelection) {
                StorageSelectionView(selection: $viewModel.selectedArchiveType, onCompletion: viewModel.handleDocumentPicker)
            }

            Button("Open Archive Folder", action: viewModel.openArchiveFolder)
                // if statement in view not possible, because the StorageSelectionView was not returning to the overview
                // after the selection has changed.
                .disabled(!PathManager.shared.archivePathType.isFileBrowserCompatible)
                .opacity(PathManager.shared.archivePathType.isFileBrowserCompatible ? 1 : 0.3)
            NavigationLink(destination: ExpertSettingsView(notSaveDocumentTagsAsPDFMetadata: $viewModel.notSaveDocumentTagsAsPDFMetadata,
                                                           documentTagsNotRequired: $viewModel.documentTagsNotRequired,
                                                           documentSpecificationNotRequired: $viewModel.documentSpecificationNotRequired,
                                                           showPermissions: viewModel.showPermissions,
                                                           resetApp: viewModel.resetApp)) {
                Text("Advanced")
            }
        } header: {
            Text("🛠 Preferences")
        }
    }

    private var statistics: some View {
        Section(header: Text("🧾 Statistics")) {
            StatisticsView()
        }
    }

    private var moreInformation: some View {
        Section(header: Text("⁉️ More Information"), footer: Text("Version \(SettingsViewModel.appVersion)")) {
            NavigationLink(destination: AboutMeView()) {
                Text("About  👤")
            }
            Link("PDF Archiver Website  🖥", destination: viewModel.pdfArchiverUrl)
            SettingsViewModel.markdownView(for: "Terms & Privacy", withKey: "Privacy")
            SettingsViewModel.markdownView(for: "Imprint", withKey: "Imprint")
            DetailRowView(name: "Contact Support  🚑") {
                sendMail(recipient: Constants.mailRecipient, subject: Constants.mailSubject)
            }
            DetailRowView(name: "Rate App ⭐️") {
                requestReview()
            }
            DetailRowView(name: "Share PDF Archiver 📱❤️🫵") {
                showActivityView = true
            }
        }
    }
}
#endif

#if !os(macOS)
#Preview {
    let viewModel = SettingsViewModel()
    SettingsView(viewModel: viewModel)
        .preferredColorScheme(.dark)
        .padding()
}
#endif
