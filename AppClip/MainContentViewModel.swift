//
//  MainContentViewModel.swift
//  AppClip
//
//  Created by Julian Kahnert on 24.10.20.
//

import ArchiveViews
import Combine
import PDFKit
import SwiftUI

final class MainContentViewModel: ObservableObject {
    static let imageConverter = ImageConverter { PathConstants.appClipTempPdfURL }

    @Published var showAppStoreOverlay = false
    @Published var showScanCompletionMessage = false

    var sharingViewModel = PDFSharingViewModel()
    var scanViewModel = ScanTabViewModel(imageConverter: imageConverter,
                                         iapService: AppClipIAPService(),
                                         documentsFinishedHandler: {})
    private var disposables = Set<AnyCancellable>()

    init() {
        $showScanCompletionMessage
            .dropFirst()
            .removeDuplicates()
            .delay(for: .seconds(1), scheduler: DispatchQueue.global(qos: .background))
            .receive(on: DispatchQueue.main)
            .compactMap { showScanCompletionMessage in
                // do not hide the app store overlay at this point
                guard !showScanCompletionMessage else { return nil }
                return true
            }
            .assign(to: &$showAppStoreOverlay)

        sharingViewModel.$pdfDocument
            .map { $0 != nil }
            .removeDuplicates()
            .delay(for: .seconds(1), scheduler: DispatchQueue.global(qos: .background))
            .receive(on: DispatchQueue.main)
            .assign(to: &$showAppStoreOverlay)

        Self.imageConverter.$processedDocumentUrl
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] outputUrl in
                guard let self = self else { return }
                if self.scanViewModel.shareDocumentAfterScan {
                    self.sharingViewModel.pdfDocument = PDFDocument(url: outputUrl)
                } else {
                    withAnimation {
                        self.showScanCompletionMessage = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                        withAnimation {
                            self.showScanCompletionMessage = false
                        }
                    }
                }
            }
            .store(in: &disposables)

        sharingViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // bubble up the change from the nested view model
                self?.objectWillChange.send()
            }
            .store(in: &disposables)

        scanViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // bubble up the change from the nested view model
                self?.objectWillChange.send()
            }
            .store(in: &disposables)
    }
}
