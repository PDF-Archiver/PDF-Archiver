//
//  SwiftUIView.swift
//  
//
//  Created by Julian Kahnert on 14.11.20.
//

import ArchiveBackend
import SwiftUI
import SwiftUIX

struct GeneralSettingsView: View {
    @AppStorage("showPreview") private var showPreview = true
    @AppStorage("fontSize") private var fontSize = 12.0

    var body: some View {
        Form {
            Toggle("Show Previews", isOn: $showPreview)
            Slider(value: $fontSize, in: 9...96) {
                Text("Font Size (\(fontSize, specifier: "%.0f") pts)")
            }
        }
        .padding(20)
        .frame(width: 350, height: 100)
    }
}

#if os(macOS)
public struct SettingsView: View {

    @ObservedObject var viewModel: MoreTabViewModel
    @State private var showMoreInformation = true

    public init(viewModel: MoreTabViewModel) {
        self.viewModel = viewModel
    }

    private enum Tabs: Hashable {
        case general, expert, storage, statistics, subscription, moreInformation
    }
    public var body: some View {
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
            subscription
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
                .maxHeight(28)
            DetailRowView(name: "Show Intro") {
                self.viewModel.showIntro()
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
            Button("Open Archive Folder" as LocalizedStringKey, action: viewModel.openArchiveFolder)
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
                    Spacer()
                    Button(action: viewModel.clearObservedFolder) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Not Selected")
                        .opacity(0.4)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.paSecondaryBackground)
            .cornerRadius(4)
            Button("Select" as LocalizedStringKey, action: viewModel.selectObservedFolder)
        }
    }

    private var statistics: some View {
        StatisticsView(viewModel: viewModel.statisticsViewModel)
            .padding(20)
            .frame(minWidth: 450, minHeight: 170)
    }

    private var subscription: some View {
        Form {
            HStack {
                Text("Status:")
                Text(viewModel.subscriptionStatus)
            }
            DetailRowView(name: "Activate/Restore Premium") {
                NotificationCenter.default.post(.showSubscriptionView)
            }
            Spacer()
            Link("Manage Subscription", destination: viewModel.manageSubscriptionUrl)
        }
        .padding(20)
        .frame(width: 450, height: 150)
    }

    private var moreInformation: some View {
        ScrollView {
            VStack(spacing: 32) {
                AboutMeView()

                Text("Version \(MoreTabViewModel.appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    DetailRowView(name: "Contact Support  🚑") {
                        NotificationCenter.default.post(Notification(name: .showSendDiagnosticsReport))
                    }
                    Spacer()
                    Link("PDF Archiver Website  🖥", destination: viewModel.pdfArchiverUrl)
                    Spacer()
                }

                VStack {
                    Text("Privacy")
                        .font(.title)
                    MoreTabViewModel.markdownView(for: "Terms & Privacy", withKey: "Privacy", withScrollView: false)
                }

                VStack {
                    Text("Imprint")
                        .font(.title)
                    MoreTabViewModel.markdownView(for: "Imprint", withKey: "Imprint", withScrollView: false)
                }
            }
        }
        .frame(width: 750, height: 450)
    }
}
#endif

#if os(macOS) && DEBG
struct SettingsView_Previews: PreviewProvider {
    @State static var viewModel = MoreTabViewModel.previewViewModel
    static var previews: some View {
        SettingsView(viewModel: viewModel)
            .previewDevice("Mac")
    }
}
#endif
