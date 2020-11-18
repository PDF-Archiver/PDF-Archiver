//
//  MainContentViewModel.swift
//  AppClip
//
//  Created by Julian Kahnert on 24.10.20.
//

import ArchiveViews
import Combine
import SwiftUI

final class MainContentViewModel: ObservableObject {
    static let imageConverter = ImageConverter(getDocumentDestination: { PathConstants.tempPdfURL })

    @Published var showAppStoreOverlay = false

    var sharingViewModel = PDFSharingViewModel()
    var scanViewModel = ScanTabViewModel(imageConverter: imageConverter,
                                         iapService: AppClipIAPService(),
                                         documentsFinishedHandler: documentsProcessingCompleted)
    private var disposables = Set<AnyCancellable>()

    init() {

        sharingViewModel.objectWillChange
            .map { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .delay(for: .seconds(1), scheduler: DispatchQueue.global(qos: .background))
            .map { [weak self] _ in
                self?.sharingViewModel.pdfDocument != nil
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$showAppStoreOverlay)

        scanViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // bubble up the change from the nested view model
                self?.objectWillChange.send()
            }
            .store(in: &disposables)
    }

    private static func documentsProcessingCompleted(error: inout Error?) {
        NotificationCenter.default.post(name: .foundProcessedDocument, object: nil)
    }
}
