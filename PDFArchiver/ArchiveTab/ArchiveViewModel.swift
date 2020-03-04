//
//  ArchiveViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable function_body_length

import ArchiveLib
import Combine
import Foundation
import os.log
import UIKit

class ArchiveViewModel: ObservableObject, SystemLogging {

    static func createDetail(with document: Document) -> DocumentDetailView {
        let viewModel = DocumentDetailViewModel(document)
        return DocumentDetailView(viewModel: viewModel)
    }

    @Published private(set) var documents: [Document] = []
    @Published var years: [String] = ["All", "2019", "2018", "2017"]
    @Published var scopeSelecton: Int = 0
    @Published var searchText = ""
    @Published var showLoadingView = true

    private var disposables = Set<AnyCancellable>()
    private let archive: Archive
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    init(_ archive: Archive = DocumentService.archive) {
        self.archive = archive

        // MARK: - Combine Stuff
        NotificationCenter.default.publisher(for: .documentChanges)
            .receive(on: DispatchQueue.main)
            .map { _ -> Bool in
                if self.showLoadingView {
                    DispatchQueue.main.async {
                        self.years = ["All"] + Array(archive.years.sorted().reversed().prefix(3))
                    }
                }
                return false
            }
            .assign(to: \.showLoadingView, on: self)
            .store(in: &disposables)

        // we assume that all documents should be loaded after 10 seconds
        // force the disappear of the loading view
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
            self.showLoadingView = false
        }

        $scopeSelecton
            .dropFirst()
            .sink { _ in
                self.selectionFeedback.prepare()
                self.selectionFeedback.selectionChanged()
            }
            .store(in: &disposables)

        // filter documents, get input from Notification, searchText or searchScope
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.global(qos: .userInitiated))
            .removeDuplicates()
            .combineLatest($scopeSelecton, NotificationCenter.default.publisher(for: .documentChanges))
            .map { (searchterm, searchscopeSelection, _) -> [Document] in

                let searchscope = self.years[searchscopeSelection]
                let scope: SearchScope
                if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: searchscope)) {
                    scope = .year(year: searchscope)
                } else {
                    scope = .all
                }

                let searchterms: [String]
                if searchterm.isEmpty {
                    searchterms = []
                } else {
                    searchterms = searchterm.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                }

                return self.archive.get(scope: scope, searchterms: searchterms, status: .tagged)
                    .sorted()
                    .reversed()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] documents in
                guard let self = self else { return }

                // workaround to skip creation of large SwiftUI List Diffs
                // TODO: should be tested on low end devices
                // TODO: add sections to improve diffing?
                if self.documents.count + documents.count < 500 {
                    self.documents = documents
                } else {
                    // seems to improve the performance A LOT - from: https://stackoverflow.com/a/58329615
                    // => no need to build a diff
                    self.documents = []
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                        self.documents = documents
                    }
                }
            }
            .store(in: &disposables)
    }

    func tapped(_ document: Document) {
        switch document.downloadStatus {
        case .iCloudDrive:

            // trigger download of the selected document
            document.download()

            // update the UI directly, by setting/updating the download status of this document
            // and triggering a notification
            document.downloadStatus = .downloading(percentDownloaded: 0.0)
            archive.update(document)
            NotificationCenter.default.post(Notification(name: .documentChanges))

            notificationFeedback.notificationOccurred(.success)

        case .local:
            os_log("Already local", log: ArchiveViewModel.log, type: .error)
        case .downloading(percentDownloaded: _):
            os_log("Already downloading", log: ArchiveViewModel.log, type: .error)
        }
    }

    func delete(at offsets: IndexSet) {
        notificationFeedback.prepare()
        for index in offsets {
            let deletedDocument = documents.remove(at: index)
            deletedDocument.delete(in: archive)
        }
        notificationFeedback.notificationOccurred(.success)
    }
}
