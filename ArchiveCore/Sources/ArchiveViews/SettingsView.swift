//
//  SwiftUIView.swift
//  
//
//  Created by Julian Kahnert on 14.11.20.
//

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
        case general, storage, statistics, subscription, moreInformation
    }
    public var body: some View {
        TabView {
            preferences
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
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
                    Label("Subscription", systemImage: "purchased.circle")
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
            DetailRowView(name: "Reset App Preferences") {
                self.viewModel.resetApp()
            }
        }
        .padding(20)
        .frame(width: 400, height: 150)
    }

    private var storage: some View {
        StorageSelectionView(selection: $viewModel.selectedArchiveType)
            .listStyle(InsetListStyle())
            .padding(20)
            .frame(width: 500, height: 250)
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
            DetailRowView(name: "Activate/Restore Subscription") {
                NotificationCenter.default.post(.showSubscriptionView)
            }
            Spacer()
            Link("Manage Subscription", destination: viewModel.manageSubscriptionUrl)
        }
        .padding(20)
        .frame(width: 400, height: 150)
    }

    private var moreInformation: some View {
        NavigationView {
            Form {
                NavigationLink("About  👤", destination: AboutMeView(), isActive: $showMoreInformation)
                Spacer()
                    .maxHeight(28)
                MoreTabViewModel.markdownView(for: "Terms of Use & Privacy Policy", withKey: "Privacy")
                MoreTabViewModel.markdownView(for: "Imprint", withKey: "Imprint")
                DetailRowView(name: "Contact Support  🚑") {
                    NotificationCenter.default.post(Notification(name: .showSendDiagnosticsReport))
                }
                Spacer()
                Link("PDF Archiver Website  🖥", destination: viewModel.macOSAppUrl)
                Text("Version \(MoreTabViewModel.appVersion)")
                    .font(.caption)
            }
            .padding(20)
        }
        .frame(width: 750, height: 450)
    }
}

struct SettingsView_Previews: PreviewProvider {
    @State static var viewModel = MoreTabViewModel.previewViewModel
    static var previews: some View {
        SettingsView(viewModel: viewModel)
            .previewDevice("Mac")
    }
}
#endif
