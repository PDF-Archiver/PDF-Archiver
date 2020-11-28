//
//  MainNavigationView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Combine
import ErrorHandling
import SwiftUI

#if os(macOS)
private typealias CustomNavigationtStyle = DefaultNavigationViewStyle
#else
private typealias CustomNavigationtStyle = StackNavigationViewStyle
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
        .sheet(isPresented: $viewModel.showSubscriptionView,
               onDismiss: viewModel.handleIAPViewDismiss) {
            IAPView(viewModel: self.viewModel.iapViewModel)
        }
        .emittingError(viewModel.error)
        .sheet(isPresented: $viewModel.isShowingMailView) {
            #if canImport(MessageUI)
            SupportMailView(subject: MainNavigationViewModel.mailSubject,
                            recipients: MainNavigationViewModel.mailRecipients,
                            result: self.$viewModel.result)
            #endif
        }
        .onChange(of: scenePhase, perform: viewModel.handleTempFilesIfNeeded)
        .handlingErrors(using: AlertErrorHandler(secondaryButton: .default(Text("Send Report"),
                                                                           action: {
                                                                            NotificationCenter.default.post(Notification(name: .showSendDiagnosticsReport))
                                                                           })))
    }

    private var sidebar: some View {
        NavigationView {
            List {
                ForEach(Tab.allCases) { tab in
                    NavigationLink(destination: viewModel.view(for: tab), tag: tab, selection: $viewModel.currentOptionalTab) {
                        Label {
                            Text(LocalizedStringKey(tab.name))
                        } icon: {
                            Image(systemName: tab.iconName)
                                .accentColor(.paDarkRed)
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
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .accentColor(.systemGray)
                }

                Section(header: Text("Tags")) {
                    ForEach(viewModel.tagCategories) { category in
                        Button {
                            viewModel.selectedTag(category)
                        } label: {
                            Label(category, systemImage: "tag")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .accentColor(.blue)
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
            ForEach(Tab.allCases) { tab in
                viewModel.view(for: tab)
                    .wrapNavigationView(when: tab != .scan)
                    .navigationViewStyle(CustomNavigationtStyle())
                    .tabItem {
                        Label(tab.name, systemImage: tab.iconName)
                    }
                    .tag(tab)
            }
        }
    }

    #if canImport(VisionKit)
    private var documentCameraView: some View {
        DocumentCameraView(
            isShown: $viewModel.scanViewModel.showDocumentScan,
            imageHandler: viewModel.scanViewModel.process)
            .edgesIgnoringSafeArea(.all)
            .statusBar(hidden: true)
    }
    #endif
}

//struct MainNavigationView_Previews: PreviewProvider {
//    @State static var viewModel = MainNavigationViewModel()
//    static var previews: some View {
//        MainNavigationView(viewModel: viewModel)
//    }
//}

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
