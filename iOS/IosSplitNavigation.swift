//
//  IosSplitNavigation.swift
//  iOS
//
//  Created by Julian Kahnert on 16.06.24.
//

import SwiftData
import SwiftUI
import OSLog

struct IosSplitNavigation: View, Log {
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(Subscription.self) private var subscription
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext

    @StateObject private var moreViewModel = SettingsViewModel()
    @State private var dropHandler = PDFDropHandler()
    @AppStorage("tutorialShown", store: .appGroup) private var tutorialShown = false

    var body: some View {
        @Bindable var navigationModel = navigationModel
        TabView(selection: $navigationModel.selectedTab) {
            Tab("Scan", systemImage: "doc.text.viewfinder", value: .scan) {
                Text("BETA: The scan tab is not implemented yet")
            }

            Tab("Archiv", systemImage: "archivebox", value: .archive) {
                archiveView
                    .modifier(ArchiveStoreLoading())
            }

            Tab("Tag", systemImage: "tag", value: .tag) {
                untaggedView
                    .modifier(ArchiveStoreLoading())
            }

            Tab("More", systemImage: "ellipsis", value: .more) {
//                settingsView
                Text("BETA: The settings tab is not implemented yet")
            }
        }
        .tabViewStyle(.tabBarOnly)
        .onChange(of: navigationModel.selectedTab) { _, _ in
            navigationModel.selectNewUntaggedDocument(in: modelContext)
        }
        .onChange(of: navigationModel.selectedDocument) { _, _ in
            guard navigationModel.untaggedMode else { return }
            navigationModel.selectNewUntaggedDocument(in: modelContext)
        }
        .sheet(isPresented: $tutorialShown.flipped) {
            OnboardingView(isPresenting: $tutorialShown.flipped)
        }
        .task {
            navigationModel.selectNewUntaggedDocument(in: modelContext)

            let changeUrlStream = NotificationCenter.default.notifications(named: .documentUpdate)
            for await _ in changeUrlStream {
                navigationModel.selectNewUntaggedDocument(in: modelContext)
            }
        }
    }

    private var loadingView: some View {
        ProgressView {
            Text("Loading documents...")
        }
        .controlSize(.extraLarge)
    }

    private var archiveView: some View {
        NavigationSplitView {
            ArchiveView()
        } detail: {
            DocumentDetailView()
        }
    }

    @ViewBuilder
    private var untaggedView: some View {
        if horizontalSizeClass == .compact {
            // We must not use a NavigationStack here, because it prevents showing the keyboard toolbar.
            // More Information: https://forums.developer.apple.com/forums/thread/736040
            UntaggedDocumentView()
        } else {
            NavigationSplitView {
                UntaggedDocumentsList()
            } detail: {
                UntaggedDocumentView()
            }
        }
    }

    private var settingsView: some View {
        NavigationStack {
            SettingsView(viewModel: moreViewModel)
        }
    }
}

extension IosSplitNavigation {
    enum TabType: String {
        case scan, tag, archive, more

        var name: LocalizedStringKey {
            switch self {
            case .scan:
                "Scan"
            case .tag:
                "Tag"
            case .archive:
                "Archive"
            case .more:
                "More"
            }
        }
        var systemImage: String {
            switch self {
            case .scan:
                "doc.text.viewfinder"
            case .tag:
                "tag"
            case .archive:
                "archivebox"
            case .more:
                "ellipsis"
            }
        }
    }
}

#if DEBUG
#Preview {
    let subscription = Subscription()
    return IosSplitNavigation()
        .environment(subscription)
        .modelContainer(previewContainer())
}
#endif
