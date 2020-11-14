//
//  MainTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Combine
import SwiftUI

struct MainNavigationView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @StateObject var viewModel = MainNavigationViewModel()

    var body: some View {
        ZStack {
            #if os(macOS)
            sidebar
            #else
            if horizontalSizeClass == .compact {
                tabbar
            } else {
                sidebar
            }
            #endif
            if viewModel.scanViewModel.showDocumentScan {
                documentCameraView
            }
            if viewModel.showSubscriptionView {
                IAPView(viewModel: self.viewModel.iapViewModel)
            }
            if viewModel.showTutorial {
                introView
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(viewModel: viewModel.alertViewModel)
        }
    }

    private var sidebar: some View {
        NavigationView {
            List {
                ForEach(viewModel.tabs) { tab in
                    NavigationLink(destination: viewModel.view(for: tab.type), tag: tab.type, selection: $viewModel.currentTab) {
                        Label {
                            Text(tab.name)
                        } icon: {
                            Image(systemName: tab.iconName)
                                .accentColor(Color(.paDarkRed))
                        }
                    }
                }

                Section(header: Text("Archive")) {
                    ForEach(viewModel.archiveCategories) { category in
                        Button {
                            viewModel.selectedArchive(category)
                        } label: {
                            Label(category, systemImage: "folder")
                        }
                    }
                }

                Section(header: Text("Tags")) {
                    ForEach(viewModel.tagCategories) { category in
                        Button {
                            viewModel.selectedTag(category)
                        } label: {
                            Label(category, systemImage: "tag")
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Documents")

            Text("Select a tab")

            // Would be great to show a thrid column in .archive case, but this is currently not possible:
            // https://github.com/JulianKahnert/NavigationExample
//            if viewModel.currentTab == .archive {
//                if let selectedDocument = viewModel.archiveViewModel.selectedDocument {
//                    ArchiveViewModel.createDetail(with: selectedDocument)
//                } else {
//                    Text("Select a tab")
//                }
//            }
        }
    }

    private var tabbar: some View {
        TabView(selection: $viewModel.currentTab) {
            ForEach(viewModel.tabs) { tab in
                viewModel.view(for: tab.type)
                    .tabItem {
                        Label(tab.name, systemImage: tab.iconName)
                    }
                    .tag(tab)
            }
        }
    }

    private var documentCameraView: some View {
        DocumentCameraView(
            isShown: $viewModel.scanViewModel.showDocumentScan,
            imageHandler: viewModel.scanViewModel.process)
            .edgesIgnoringSafeArea(.all)
            .statusBar(hidden: true)
    }

    private var introView: some View {
        IntroView()
            .edgesIgnoringSafeArea(.all)
            .statusBar(hidden: true)
    }
}

//struct MainTabView_Previews: PreviewProvider {
//    @State static var viewModel = MainNavigationViewModel()
//    static var previews: some View {
//        MainTabView(viewModel: viewModel)
//    }
//}
