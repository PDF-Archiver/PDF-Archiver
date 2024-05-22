//
//  ContentView.swift
//  AppClip
//
//  Created by Julian Kahnert on 10.10.20.
//

import Combine
import StoreKit
import SwiftUI

struct MainContentView: View {

    @StateObject var viewModel = MainContentViewModel()

    var body: some View {
        ZStack {
            ScanTabView(viewModel: viewModel.scanViewModel)

            if viewModel.showScanCompletionMessage {
                documentScanCompleted
            }

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

    private var documentScanCompleted: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark")
                .font(.largeTitle, weight: .bold)
                .foregroundColor(.systemGreen)
            Label("Processing completed", systemImage: "doc.text")
                .font(.title2)
        }
        .padding()
        .background(.background)
        .cornerRadius(8)
        .shadow(color: .paDarkGray, radius: 15)
        .transition(.scale)
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
