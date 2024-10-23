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
    @Environment(Subscription.self) private var subscription
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var moreViewModel = SettingsViewModel()
    @State private var dropHandler = PDFDropHandler()
    @State private var selectedDocumentId: String?
    @AppStorage("selectedTab", store: .appGroup) private var selectedTab: TabType = .scan
    @AppStorage("tutorialShown", store: .appGroup) private var tutorialShown = false

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

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Scan", systemImage: "doc.text.viewfinder", value: .scan) {
                Text("BETA: The scan tab is not implemented yet")
            }

            Tab("Archiv", systemImage: "archivebox", value: .archive) {
                archiveView
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
    }

    private var archiveView: some View {
        NavigationSplitView {
            ArchiveView(selectedDocumentId: $selectedDocumentId)
        } detail: {
            DocumentDetailView(documentId: $selectedDocumentId, untaggedMode: Binding(get: {
                selectedTab == .tag
            }, set: { value in
                selectedTab = value ? .tag : .archive
            }))
        }
        .onAppear {
            // unselect possibly selected document because it might be an untagged document
            selectedDocumentId = nil
        }
    }
    
    @ViewBuilder
    private var untaggedView: some View {
        if horizontalSizeClass == .compact {
            NavigationStack {
                UntaggedDocumentView(documentId: $selectedDocumentId, selectDocumentItself: true)
            }
        } else {
            NavigationSplitView {
                UntaggedDocumentsList(selectedDocumentId: $selectedDocumentId)
            } detail: {
                UntaggedDocumentView(documentId: $selectedDocumentId)
            }
        }
    }

    private var settingsView: some View {
        NavigationStack {
            SettingsView(viewModel: moreViewModel)
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
