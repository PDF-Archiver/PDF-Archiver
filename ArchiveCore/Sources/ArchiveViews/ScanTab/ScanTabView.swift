//
//  ScanTabViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 31.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import SwiftUIX

public struct ScanTabView: View {
    @ObservedObject var viewModel: ScanTabViewModel
    @State private var opacity = 0.0

    private let maxFrameHeight: CGFloat = {
        #if os(macOS)
        return 500
        #else
        return .infinity
        #endif
    }()

    public init(viewModel: ScanTabViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack {
            Spacer()
            staticInfo
            Spacer()
            VStack(alignment: .center) {
                ProgressView(viewModel.progressLabel, value: viewModel.progressValue)
                    .opacity(viewModel.progressValue > 0.0 ? 1 : 0)
                #if os(macOS)
                importFieldView
                #else
                scanButton
                #endif
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxHeight: maxFrameHeight)
        .padding(EdgeInsets(top: 32.0, leading: 16.0, bottom: 32.0, trailing: 16.0))
        .onDrop(of: [.image, .pdf, .fileURL],
                delegate: viewModel)
        .navigationTitle(Text(""))
    }

    @ViewBuilder
    private var staticInfo: some View {
        #if os(macOS)
        let content: LocalizedStringKey = "Import your documents, tag them and find them sorted in your iCloud Drive."
        #else
        let content: LocalizedStringKey = "Scan your documents, tag them and find them sorted in your iCloud Drive."
        #endif
        VStack(alignment: .leading) {
            Image("Logo")
                .resizable()
                .frame(width: 100, height: 100, alignment: .leading)
                .padding()
            Text("Welcome to")
                .font(.largeTitle)
                .fontWeight(.heavy)
            Text("PDF Archiver")
                .foregroundColor(.paDarkRed)
                .font(.largeTitle)
                .fontWeight(.heavy)
            Text(content)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
        .padding(16.0)
        .foregroundColor(.paDarkGray)
        .opacity(opacity)
        .onAppear {
            withAnimation {
                opacity = 1.0
            }
        }
    }

    private var importFieldView: some View {
        Label("Drag'n'Drop to import PDF or Image", systemImage: "doc.text.viewfinder")
            .foregroundColor(.paWhite)
            .padding(.horizontal, 50)
            .padding(.vertical, 20)
            .background(.paDarkGray)
            .cornerRadius(8)
    }

    #if !os(macOS)
    private var scanButton: some View {
        VStack(spacing: 8) {
            Button(action: {
                self.viewModel.startScanning()
            }, label: {
                Text("Scan")
            }).buttonStyle(FilledButtonStyle())
            .keyboardShortcut("s")
            Toggle("Share document after scan", isOn: $viewModel.shareDocumentAfterScan)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: 400)
    }
    #endif
}

#if DEBUG
import Combine
import StoreKit
struct ScanTabView_Previews: PreviewProvider {
    private class ImageConverter: ImageConverterAPI {
        var totalDocumentCount = Atomic<Int>(5)
        func handle(_ url: URL) throws {}
        func startProcessing() throws {}
        func stopProcessing() {}
        func getOperationCount() -> Int { 4 }
    }

    private class MockIAPService: IAPServiceAPI {
        var productsPublisher: AnyPublisher<Set<SKProduct>, Never> {
            Just([]).eraseToAnyPublisher()
        }
        var appUsagePermitted = true
        var appUsagePermittedPublisher: AnyPublisher<Bool, Never> {
            Just(appUsagePermitted).eraseToAnyPublisher()
        }
        func buy(subscription: IAPService.SubscriptionType) throws {}
        func restorePurchases() {}
    }

    static var previews: some View {
        // swiftlint:disable:next trailing_closure
        ScanTabView(viewModel: ScanTabViewModel(imageConverter: ImageConverter(), iapService: MockIAPService()))
        .frame(maxWidth: .infinity)
        .padding()
    }
}
#endif
