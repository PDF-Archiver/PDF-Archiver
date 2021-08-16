//
//  ArchiveViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable function_body_length

import Combine
import Foundation
import SwiftUI
import SwiftUIX

final class ArchiveViewModel: ObservableObject, Log {

    private static let defaultYears = ["All", "2020", "2019", "2018", "2017"]

    @Published private(set) var selectedDocument: Document?
    @Published private(set) var documents: [Document] = []
    @Published private(set) var years: [String] = defaultYears
    @Published var scopeSelection: Int = 0
    @Published var searchText = ""
    @Published var showLoadingView = true

    @Published var availableFilters: [FilterItem] = []
    @Published var selectedFilters: [FilterItem] = []

    private var disposables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "ArchiveViewModel WorkQueue", qos: .userInitiated)
    private let archiveStore: ArchiveStore
    private var detailViewModels = [Document: DocumentDetailViewModel]()

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
            .receive(on: queue)
            .map { (searchTerm, _) -> [FilterItem] in

                // only change scope when there is a non-empty searchTerm
                guard !searchTerm.isEmpty else { return [] }

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
            .debounce(for: .milliseconds(100), scheduler: queue)
            .removeDuplicates()
            .combineLatest($scopeSelection, archiveStore.$documents, $selectedFilters)
            .receive(on: queue)
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

                // we need to get the year values on the main thread to avoid race conditions,
                // e.g. after document updates
                let years = DispatchQueue.main.sync {
                    self.years
                }

                if let searchScope = years.get(at: searchScopeSelection),
                   searchScope.isNumeric {
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
        queue.async {
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

    func createDetail(with document: Document) -> some View {
        // This function might be called multiple times for the same document.
        // If we create a new view model on every call, all changes to the view model (e.g. showActivityView state)
        // would be reset. This would result in a closing ActivityView directly after it was presented.
        let viewModel = detailViewModels[document, default: DocumentDetailViewModel(document)]
        detailViewModels[document] = viewModel
        return DocumentDetailView(viewModel: viewModel)
    }

    private static func getDateFilters(from searchterm: String) -> [FilterItem] {
        guard let date = DateParser.parse(searchterm)?.date else { return [] }
        return [.year(date), .yearMonth(date), .yearMonthDay(date)]
    }
}
