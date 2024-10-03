//
//  IosSplitNavigation.swift
//  iOS
//
//  Created by Julian Kahnert on 16.06.24.
//

import SwiftUI
import OSLog

struct IosSplitNavigation: View {
    @Environment(Subscription.self) var subscription

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
            Text("Test")
                .tabItem {
                    Label(TabType.scan.name, systemImage: TabType.scan.systemImage)
                }
                .tag(TabType.scan)

            archiveView
                .tabItem {
                    Label(TabType.archive.name, systemImage: TabType.archive.systemImage)
                }
                .tag(TabType.archive)

            UntaggedDocumentsList(selectedDocumentId: $selectedDocumentId)
                .tabItem {
                    Label(TabType.tag.name, systemImage: TabType.tag.systemImage)
                }
                .tag(TabType.tag)

            settingsView
                .tabItem {
                    Label(TabType.more.name, systemImage: TabType.more.systemImage)
                }
                .tag(TabType.more)
        }


//        TabView(selection: $selection) {
//            Tab("Scan", systemImage: "doc.text.viewfinder", value: .scan) {
//                Text("1")
//            }
//            Tab("Tag", systemImage: "tag", value: .tag) {
//                NavigationSplitView {
//                    UntaggedDocumentsList(selectedDocumentId: $selectedDocumentId)
//                } detail: {
//                    UntaggedDocumentView(documentId: $selectedDocumentId)
////                        .sheet(isPresented: subscription.isSubscribed, content: {
////                            InAppPurchaseView(onCancel: {
////                                untaggedMode = false
////                            })
////                        })
//                }
//            }
//
//            Tab("Archiv", systemImage: "archivebox", value: .archiv) {
//                ArchiveView(selectedDocumentId: $selectedDocumentId)
//            }
//            
//            Tab("More", systemImage: "ellipsis", value: .more) {
//                #warning("TODO: implement more tab")
//                Text("Settings view")
//            }
//        }
//        .tabViewStyle(.sidebarAdaptable)

    }

    private var archiveView: some View {
        NavigationSplitView(sidebar: {
            ArchiveView(selectedDocumentId: $selectedDocumentId)
        }, detail: {
            DocumentDetailView(documentId: selectedDocumentId, untaggedMode: Binding(get: {
                selectedTab == .tag
            }, set: { value in
                selectedTab = value ? .tag : .archive
            }))
        })
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
