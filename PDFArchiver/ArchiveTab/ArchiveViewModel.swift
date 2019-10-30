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

class ArchiveViewModel: ObservableObject {

    @Published private(set) var documents: [Document] = []
    @Published var years: [String] = ["all", "2019", "2018", "2017"]
    @Published var scopeSelecton: Int = 0
    @Published var searchText = ""

    private var disposables = Set<AnyCancellable>()

    init() {

        // filter documents, get input from Notification, searchText or searchCcope
        NotificationCenter.default.publisher(for: Notification.Name.documentChanges)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global(qos: .userInitiated))
            .removeDuplicates()
            .combineLatest($searchText, $scopeSelecton)
            .map { (_, searchterm, searchscopeSelection) -> [Document] in

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
                    searchterms = [searchterm]
                }

                return DocumentService.archive.get(scope: scope, searchterms: searchterms, status: .tagged)
                    .sorted()
                    .reversed()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] documents in
                guard let self = self else { return }

                // workaround to skip creation of large SwiftUI List Diffs
                // TODO: should be tested on low end devices
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
