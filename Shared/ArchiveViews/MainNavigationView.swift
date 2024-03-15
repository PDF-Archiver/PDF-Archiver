//
//  MainNavigationView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Combine
import SwiftUI

#if os(macOS)
private typealias CustomNavigationStyle = DefaultNavigationViewStyle
#else
private typealias CustomNavigationStyle = StackNavigationViewStyle
#endif

public struct MainNavigationView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @ObservedObject public var viewModel: MainNavigationViewModel
    @Environment(\.scenePhase) private var scenePhase

    public init(viewModel: MainNavigationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            #if os(macOS)
            sidebar
            #else
            if horizontalSizeClass == .compact {
                tabbar
            } else {
                sidebar
            }
            if viewModel.scanViewModel.showDocumentScan {
                documentCameraView
            }
            #endif
        }
        .intro(when: $viewModel.showTutorial)
        .sheet(item: $viewModel.sheetType,
               onDismiss: viewModel.handleIAPViewDismiss) { sheetType in
            viewModel.getView(for: sheetType)
        }
        .onChange(of: scenePhase, perform: viewModel.handleTempFilesIfNeeded)
        .alert(item: $viewModel.alertDataModel, content: Alert.create(from:))
    }

    private var sidebar: some View {
        NavigationView {
            List {
                ForEach(Tab.allCases) { tab in
                    NavigationLink(destination: viewModel.lazyView(for: tab), tag: tab, selection: $viewModel.currentTab) {
                        Label {
                            Text(tab.name)
                        } icon: {
                            Image(systemName: tab.iconName)
                                .accentColor(.paDarkRed)
                        }
                    }
                }

                Section(header: Text("Archive").foregroundColor(.paDarkRed)) {
                    ForEach(viewModel.archiveCategories) { category in
                        Button {
                            viewModel.selectedArchive(category)
                        } label: {
                            Label(category, systemImage: "calendar")
                                .labelStyle(SidebarLabelStyle(iconColor: .systemGray, titleColor: .systemGray))
                                // Make the whole width tappable
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }

                Section(header: Text("Tags").foregroundColor(.paDarkRed)) {
                    ForEach(viewModel.tagCategories) { category in
                        Button {
                            viewModel.selectedTag(category)
                        } label: {
                            Label(category.capitalized, systemImage: "tag")
                                .labelStyle(SidebarLabelStyle(iconColor: .blue, titleColor: .systemGray))
                                // Make the whole width tappable
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Documents")

            Text("Start by selecting Scan, Tag or Archive in the sidebar.")

            // Would be great to show a third column in .archive case, but this is currently not possible:
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
        TabView(selection: viewModel.unwrappedCurrentTab) {
            ForEach(Tab.allCases) { tab in
                viewModel.lazyView(for: tab)
                    .wrapNavigationView(when: tab != .scan)
                    .navigationViewStyle(CustomNavigationStyle())
                    .tabItem {
                        Label(tab.name, systemImage: tab.iconName)
                    }
                    .tag(tab)
            }
        }
    }

    #if !os(macOS)
    private var documentCameraView: some View {
        DocumentCameraView(
            isShown: $viewModel.scanViewModel.showDocumentScan,
            imageHandler: viewModel.scanViewModel.process)
            .edgesIgnoringSafeArea(.all)
            .statusBar(hidden: true)
    }
    #endif
}

// struct MainNavigationView_Previews: PreviewProvider {
//    @State static var viewModel = MainNavigationViewModel()
//    static var previews: some View {
//        MainNavigationView(viewModel: viewModel)
//    }
// }

fileprivate extension View {

    @ViewBuilder
    func intro(when value: Binding<Bool>) -> some View {
        if value.wrappedValue {
            ZStack {
                self
                    .redacted(reason: .placeholder)
                    .blur(radius: 15)

                OnboardingView(isPresenting: value)
            }
        } else {
            self
        }
    }
}
