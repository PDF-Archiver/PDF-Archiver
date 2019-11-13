//
//  ArchiveViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Combine
import Foundation
import os.log

class ArchiveViewModel: ObservableObject, SystemLogging {

    static func createDetail(with document: Document) -> DocumentDetailView {
        let viewModel = DocumentDetailViewModel(document)
        return DocumentDetailView(viewModel: viewModel)
    }

    @Published private(set) var documents: [Document] = []
    @Published var years: [String] = ["all", "2019", "2018", "2017"]
    @Published var scopeSelecton: Int = 0
    @Published var searchText = ""

    private var disposables = Set<AnyCancellable>()
    private let archive: Archive

    init(_ archive: Archive = DocumentService.archive) {
        self.archive = archive
        buildCombineStuff()

        // Trigger creation of documents array, if no documents could be found.
        // This might happen, when we start in another view and all previous notifications were not caught.
        if documents.isEmpty {
            triggerUpdate()
        }
    }

    func tapped(_ document: Document) {
        switch document.downloadStatus {
        case .iCloudDrive:
            document.download()
            archive.update(document)
            triggerUpdate()
        case .local:
            os_log("Already local", log: ArchiveViewModel.log, type: .error)
        case .downloading(percentDownloaded: _):
            os_log("Already downloading", log: ArchiveViewModel.log, type: .error)
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let deletedDocument = documents.remove(at: index)
            deletedDocument.delete(in: archive)
        }
    }

    private func triggerUpdate() {
        NotificationCenter.default.post(Notification(name: .documentChanges))
    }

    private func buildCombineStuff() {

        // filter documents, get input from Notification, searchText or searchCcope
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.global(qos: .userInitiated))
            .removeDuplicates()
            .combineLatest($scopeSelecton, NotificationCenter.default.publisher(for: Notification.Name.documentChanges))
            // TODO: debounce here? would it delay all other steps? fix: stop flickering after multiple notifications
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
}
