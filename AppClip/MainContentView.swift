//
//  ContentView.swift
//  AppClip
//
//  Created by Julian Kahnert on 10.10.20.
//

import ArchiveViews
import ArchiveBackend
import Combine
import SwiftUI
import SwiftUIX
import StoreKit

struct MainContentView: View {

    @StateObject var viewModel = MainContentViewModel()

    var body: some View {
        ZStack {
            ScanTabView(viewModel: viewModel.scanViewModel)

            if viewModel.sharingViewModel.pdfDocument != nil {
                PDFSharingView(viewModel: viewModel.sharingViewModel)
            }

            if viewModel.scanViewModel.showDocumentScan {
                documentCameraView
            }
        }
        .sheet(item: $viewModel.sharingViewModel.sharingUrl) { sharingUrl in
            AppActivityView(activityItems: [sharingUrl])
        }
        .appStoreOverlay(isPresented: $viewModel.showAppStoreOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
    }

    private var documentCameraView: some View {
        DocumentCameraView(isShown: $viewModel.scanViewModel.showDocumentScan,
                           imageHandler: viewModel.scanViewModel.process)
            .edgesIgnoringSafeArea(.all)
            .statusBar(hidden: true)
    }
}

extension URL: Identifiable {
    public var id: String { path }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainContentView()
    }
}
#endif
