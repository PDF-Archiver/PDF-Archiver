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
//    typealias Element = Document

    @Published private(set) var documents: [Document] = []
    @Published var years: [String] = ["all", "2019", "2018", "2017"]
    @Published var scopeSelecton: Int = 0

    @Published var searchText = ""
    @Published var searchScope = "all"

//    private var allDocuments: [Document] = [] {
//        didSet {
//            let allFoldeNames = self.allDocuments
//                .map { $0.folder }
//                .filter { CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: $0)) }
//
//            let folderNames = Set(allFoldeNames)
//                .sorted()
//                .reversed()
//                .prefix(3)
//
//            self.years = Array(folderNames)
//        }
//    }
    private var disposables = Set<AnyCancellable>()
//    var allSearchElements: Set<Document> {
//        Set(allDocuments)
//    }

    init() {
        // filter documents
        $searchText
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global(qos: .userInitiated))
            .removeDuplicates()
            .combineLatest($scopeSelecton)
            .map { (searchterm, searchscopeSelection) -> Set<Document> in
//                self.filter(by: [searchterm, searchscope])

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

//                let tmp = DocumentService.archive.get(scope: scope, searchterms: searchterms, status: .tagged)
                return DocumentService.archive.get(scope: scope, searchterms: searchterms, status: .tagged)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] documents in
                guard let self = self else { return }

                // seems to improve the performance A LOT - from: https://stackoverflow.com/a/58329615
                // => no need to build a diff
                self.documents = []
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    self.documents = Array(documents).sorted().reversed()
                }
            }
            .store(in: &disposables)

        // get all documents
//        allDocuments = Array(DocumentService.archive.get(scope: .all, searchterms: [], status: .tagged))
    }
}
