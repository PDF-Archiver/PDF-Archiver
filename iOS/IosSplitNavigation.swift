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
    @Environment(\.modelContext) private var modelContext

    @StateObject private var moreViewModel = SettingsViewModel()
    @State private var dropHandler = PDFDropHandler()
    @State private var selectedTaggedDocumentId: String?
    @State private var selectedUntaggedDocumentId: String?
    @AppStorage("selectedTab", store: .appGroup) private var selectedTab: TabType = .scan
    @AppStorage("tutorialShown", store: .appGroup) private var tutorialShown = false

    var body: some View {
        TabView(selection: $selectedTab) {
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
        .onChange(of: selectedTab) { _, _ in
            selectNewUntaggedDocument()
        }
        .onChange(of: selectedUntaggedDocumentId) { _, _ in
            selectNewUntaggedDocument()
        }
        .task {
            selectNewUntaggedDocument()

            let changeUrlStream = NotificationCenter.default.notifications(named: .documentUpdate)
            for await _ in changeUrlStream {
                selectNewUntaggedDocument()
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
            ArchiveView(selectedDocumentId: $selectedTaggedDocumentId)
        } detail: {
            DocumentDetailView(documentId: $selectedTaggedDocumentId, untaggedMode: Binding(get: {
                selectedTab == .tag
            }, set: { value in
                selectedTab = value ? .tag : .archive
            }))
        }
    }

    @ViewBuilder
    private var untaggedView: some View {
        if horizontalSizeClass == .compact {
            NavigationStack {
                UntaggedDocumentView(documentId: $selectedUntaggedDocumentId)
            }
        } else {
            NavigationSplitView {
                UntaggedDocumentsList(selectedDocumentId: $selectedUntaggedDocumentId)
            } detail: {
                UntaggedDocumentView(documentId: $selectedUntaggedDocumentId)
            }
        }
    }

    private var settingsView: some View {
        NavigationStack {
            SettingsView(viewModel: moreViewModel)
        }
    }

    private func selectNewUntaggedDocument() {
        guard case TabType.tag = selectedTab,
              selectedUntaggedDocumentId == nil else { return }

        do {
            let predicate = #Predicate<Document> {
                !$0.isTagged
            }

            var descriptor = FetchDescriptor<Document>(
                predicate: predicate,
                sortBy: [SortDescriptor(\Document.id)]
            )
            descriptor.fetchLimit = 1
            let documents = try modelContext.fetch(descriptor)
            if let document = documents.first {
                Task {
                    await NewArchiveStore.shared.startDownload(of: document.url)
                }
            }
            selectedUntaggedDocumentId = documents.first?.id
        } catch {
            selectedUntaggedDocumentId = nil
            Logger.newDocument.errorAndAssert("Found error \(error)")
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
