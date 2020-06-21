//
//  MainTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var viewModel: MainTabViewModel

    var body: some View {
        ZStack {
            tabViews
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

    private var tabViews: some View {
        TabView(selection: $viewModel.currentTab) {
            ScanTabView(viewModel: viewModel.scanViewModel)
                .tabItem {
                    VStack {
                        Image(systemName: "doc.text.viewfinder")
                        Text("Scan")
                    }
                }.tag(0)
            TagTabView(viewModel: viewModel.tagViewModel)
                .tabItem {
                    VStack {
                        Image(systemName: "tag")
                        Text("Tag")
                    }
                }.tag(1)
            ArchiveView(viewModel: viewModel.archiveViewModel)
                .tabItem {
                    VStack {
                        Image(systemName: "archivebox")
                        Text("Archive")
                    }
                }.tag(2)
            MoreTabView(viewModel: viewModel.moreViewModel)
                .tabItem {
                    VStack {
                        Image(systemName: "ellipsis")
                        Text("More")
                    }
                }.tag(3)
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

struct MainTabView_Previews: PreviewProvider {
    @State static var viewModel = MainTabViewModel()
    static var previews: some View {
        MainTabView(viewModel: viewModel)
    }
}
