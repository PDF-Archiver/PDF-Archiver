//
//  ArchiveViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable function_body_length

// import ArchiveCore
import Combine
import Foundation
import SwiftUI

final class ArchiveViewModel: ObservableObject, Log {

    static func createDetail(with document: Document) -> DocumentDetailView {
        let viewModel = DocumentDetailViewModel(document)
        return DocumentDetailView(viewModel: viewModel)
    }
    private static let defaultYears = ["All", "2020", "2019", "2018", "2017"]

    @Published private(set) var selectedDocument: Document?
    @Published private(set) var documents: [Document] = []
    @Published var years: [String] = defaultYears
    @Published var scopeSelection: Int = 0
    @Published var searchText = ""
    @Published var showLoadingView = true

    @Published var availableFilters: [FilterItem] = []
    @Published var selectedFilters: [FilterItem] = []

    private var disposables = Set<AnyCancellable>()
    private let archiveStore: ArchiveStore

    init(_ archiveStore: ArchiveStore = ArchiveStore.shared) {
        self.archiveStore = archiveStore

        // MARK: - Combine Stuff
        archiveStore.$state
            .map { state -> Bool in
                state == .uninitialized
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.showLoadingView, on: self)
            .store(in: &disposables)

        archiveStore.$years
            .map { years -> [String] in
                if years.isEmpty {
                    return Self.defaultYears
                } else {
                    return ["All"] + Array(years.sorted().reversed().prefix(4))
                }
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { years in
                self.years = years
            }
            .store(in: &disposables)

        $scopeSelection
            .dropFirst()
            .sink { _ in
                self.selectedFilters = self.selectedFilters.filter(\.isTag)
                FeedbackGenerator.selectionChanged()
            }
            .store(in: &disposables)

        $searchText
            .combineLatest($scopeSelection)
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            // only change scope when there is a non-empty searchTerm
            .filter { !$0.0.isEmpty }
            .map { (searchTerm, _) -> [FilterItem] in
                var filters = Self.getDateFilters(from: searchTerm)
                let lowercasedSearchTerm = searchTerm.lowercased()
                let tagFilters = TagStore.shared.getAvailableTags(with: [lowercasedSearchTerm])
                    .map { $0.lowercased() }
                    .sorted { lhs, rhs in
                        if lhs.starts(with: lowercasedSearchTerm) == rhs.starts(with: lowercasedSearchTerm) {
                            return lhs < rhs
                        } else {
                            return lhs.starts(with: lowercasedSearchTerm)
                        }
                    }
                    .prefix(10)
                    .map(FilterItem.tag)
                filters.append(contentsOf: tagFilters)

                return filters
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.availableFilters, on: self)
            .store(in: &disposables)

        // filter documents, get input from Notification, searchText or searchScope
        $searchText
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.global(qos: .userInitiated))
            .removeDuplicates()
            .combineLatest($scopeSelection, archiveStore.$documents, $selectedFilters)
            .map { (searchTerm, searchScopeSelection, documents, selectedFilters) -> [Document] in

                var searchTerms: [String] = []
                if searchTerm.isEmpty {
                    searchTerms = []
                } else {
                    searchTerms = searchTerm.slugified(withSeparator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .whitespacesAndNewlines)

                }

                var currentDocuments = documents

                let searchScope = self.years[searchScopeSelection]
                if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: searchScope)) {
                    // found a year - it should be used as a searchTerm
                    currentDocuments = currentDocuments.filter { $0.folder == searchScope }
                }

                return currentDocuments
                    .filter { $0.taggingStatus == .tagged }
                    .filter(by: selectedFilters)
                    // filter by fuzzy search + sort
                    .fuzzyMatchSorted(by: searchTerms)
                    // sort: new > old
                    .reversed()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] documents in
                guard let self = self else { return }

//                #if DEBUG
//                let sortedDocuments = documents.sorted().reversed()
//                let documentsDiff = diff(old: documents.map(\.path).map(\.path), new: sortedDocuments.map(\.path).map(\.path))
//                if !documentsDiff.isEmpty {
//                    Self.log.assertOrError("Documents are not sorted")
//                }
//                #endif
                self.documents = documents
            }
            .store(in: &disposables)
    }

    func tapped(_ document: Document) {
        log.debug("Tapped document: \(document.filename)")
        switch document.downloadStatus {
        case .remote:

            // trigger download of the selected document
            do {
                try archiveStore.download(document)
            } catch {
                NotificationCenter.default.postAlert(error)
            }

            FeedbackGenerator.notify(.success)

        case .local:
            selectedDocument = document
        case .downloading:
            log.debug("Already downloading")
        }
    }

    func delete(at offsets: IndexSet) {
        let documentsToDelete = offsets.map { self.documents[$0] }
        DispatchQueue.global(qos: .userInitiated).async {
            var deletedDocuments = [Document]()
            do {
                defer {
                    DispatchQueue.main.async {
                        self.documents.removeAll { deletedDocuments.contains($0) }
                    }
                }

                for document in documentsToDelete {
                    try self.archiveStore.delete(document)
                    deletedDocuments.append(document)
                }
                FeedbackGenerator.notify(.success)
            } catch {
                NotificationCenter.default.postAlert(error)
            }
        }
    }

    func selected(filterItem: FilterItem) {
        withAnimation {
            if let index = availableFilters.firstIndex(of: filterItem) {
                availableFilters.remove(at: index)

                selectedFilters.append(filterItem)
                selectedFilters.sort()
            } else if let index = selectedFilters.firstIndex(of: filterItem) {
                selectedFilters.remove(at: index)
            }

            searchText = ""
        }
    }

    private static func getDateFilters(from searchterm: String) -> [FilterItem] {
        guard let date = DateParser.parse(searchterm)?.date else { return [] }
        return [.year(date), .yearMonth(date), .yearMonthDay(date)]
    }
}
