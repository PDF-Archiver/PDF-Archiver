//
//  SearchIndex.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 23.10.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

protocol Searchable: Hashable {
    var searchTerm: String { get }
}

protocol Searcher {
    associatedtype Element: Searchable

    var allSearchElements: Set<Element> { get }

    func filterBy(_ searchTerm: String) -> Set<Element>
    func filterBy(_ searchTerms: [String]) -> Set<Element>
}

extension Searcher {

    func filterBy(_ searchTerm: String) -> Set<Element> {
        return filterBy(searchTerm, allSearchElements)
    }

    func filterBy(_ searchTerms: [String]) -> Set<Element> {
        // all searchTerms must be machted

        var currentElements = allSearchElements
        for searchTerm in searchTerms {
            currentElements = filterBy(searchTerm, currentElements)
        }
        return currentElements
    }

    private func filterBy(_ searchTerm: String, _ searchElements: Set<Element>) -> Set<Element> {
        return searchElements.filter { $0.searchTerm.contains(searchTerm) }
    }
}
