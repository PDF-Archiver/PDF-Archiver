//
//  SwiftUIView.swift
//
//  Created by Julian Kahnert on 14.11.20.
//

import OSLog
import SwiftData
import SwiftUI

#if os(macOS)
struct SettingsViewMacOS: View {

    @AppStorage("tutorialShown", store: .appGroup) private var tutorialShown = false
    @ObservedObject var viewModel: SettingsViewModel
    @Query private var documents: [Document]

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    private enum Tabs: Hashable {
        case general, expert, storage, statistics, subscription, moreInformation
    }
    var body: some View {
        TabView {
            preferences
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            expertSettings
                .tabItem {
                    Label("Advanced", systemImage: "hand.point.up.braille")
                }
                .tag(Tabs.expert)
            storage
                .tabItem {
                    Label("Storage", systemImage: "internaldrive")
                }
                .tag(Tabs.storage)
            statistics
                .tabItem {
                    Label("Statistics", systemImage: "list.number")
                }
                .tag(Tabs.statistics)
            Form {
                PremiumSectionView()
            }
            .tabItem {
                Label("Premium", systemImage: "purchased.circle")
            }
            .tag(Tabs.subscription)
            moreInformation
                .tabItem {
                    Label("More", systemImage: "info.circle")
                }
                .tag(Tabs.moreInformation)
        }
    }

    private var preferences: some View {
        Form {
            Picker(selection: $viewModel.selectedQualityIndex, label: Text("PDF Quality")) {
                ForEach(0..<viewModel.qualities.count, id: \.self) {
                    Text(self.viewModel.qualities[$0])
                }
            }
            Spacer()
            DetailRowView(name: "Show Intro") {
                withAnimation {
                    tutorialShown = false
                }
            }
            Spacer()
            ProgressView("Finder Tag Update", value: viewModel.finderTagUpdateProgress)
                .opacity(viewModel.finderTagUpdateProgress > 0 ? 1 : 0)
            DetailRowView(name: "Update Finder Tags") {
                Logger.settings.debug("DEBUGGING: Starting update")
                viewModel.updateFinderTags(from: documents)

                Logger.settings.debug("DEBUGGING: completing task")
            }
        }
        .padding(20)
        .frame(width: 450, height: 150)
    }

    private var expertSettings: some View {
        ExpertSettingsView(notSaveDocumentTagsAsPDFMetadata: $viewModel.notSaveDocumentTagsAsPDFMetadata,
                           documentTagsNotRequired: $viewModel.documentTagsNotRequired,
                           documentSpecificationNotRequired: $viewModel.documentSpecificationNotRequired,
                           showPermissions: nil,
                           resetApp: viewModel.resetApp)
        .padding()
        .frame(width: 450, height: 160)
    }

    private var storage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Archive")
                .font(.title)
                .foregroundColor(.paDarkRed)
                .padding(.vertical, 8)
            StorageSelectionView(selection: $viewModel.selectedArchiveType, onCompletion: viewModel.handleDocumentPicker)
                .listStyle(InsetListStyle())
            Button("Open Archive Folder", action: viewModel.openArchiveFolder)
                .frame(maxWidth: .infinity)
            Divider()
                .padding(.vertical, 10)
            Text("Observed Folder")
                .font(.title)
                .foregroundColor(.paDarkRed)
                .padding(.bottom, 4)
            observedFolderSelection
                .padding(.vertical, 10)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(width: 500, height: 375)
    }

    private var observedFolderSelection: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                if let observedFolderURL = viewModel.observedFolderURL {
                    Text(observedFolderURL.path)
                } else {
                    Text("Not Selected")
                        .opacity(0.4)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.paSecondaryBackground))
            .cornerRadius(4)
            if viewModel.observedFolderURL != nil {
                Button(action: viewModel.clearObservedFolder) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Select", action: viewModel.selectObservedFolder)
            }
        }
    }

    private var statistics: some View {
        StatisticsView()
            .padding(20)
            .frame(minWidth: 450, minHeight: 170)
    }

    private var moreInformation: some View {
        ScrollView {
            VStack(spacing: 32) {
                AboutMeView()

                Text("Version \(SettingsViewModel.appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    DetailRowView(name: "Contact Support  🚑") {
                        sendMail(recipient: Constants.mailRecipient, subject: Constants.mailSubject)
                    }
                    Spacer()
                    Link("PDF Archiver Website  🖥", destination: viewModel.pdfArchiverUrl)
                    Spacer()
                }

                HStack {
                    Link("Terms of Use", destination: viewModel.termsOfUseUrl)
                    Link("Privacy Policy", destination: viewModel.privacyPolicyUrl)
                }

                VStack {
                    Text("Privacy")
                        .font(.title)
                    SettingsViewModel.markdownView(for: "Terms & Privacy", withKey: "Privacy", withScrollView: false)
                }

                VStack {
                    Text("Imprint")
                        .font(.title)
                    SettingsViewModel.markdownView(for: "Imprint", withKey: "Imprint", withScrollView: false)
                }
            }
        }
        .frame(width: 750, height: 450)
    }
}

#if DEBUG
struct SettingsPreviewView: View {
    @State var viewModel = SettingsViewModel()
    var body: some View {
        SettingsViewMacOS(viewModel: viewModel)
    }
}

#Preview("Test", traits: .sizeThatFitsLayout) {
    SettingsPreviewView()
        .modelContainer(previewContainer())
}
#endif
#endif
