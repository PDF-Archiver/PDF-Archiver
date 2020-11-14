//
//  Search.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 13.11.18.
//

import Foundation

/// Scope, which defines the documents that should be searched.
public enum SearchScope {

    /// Search the whole archive.
    case all

    /// Search in a specific year.
    case year(year: String)
}

///// Protocol for objects which should be searched.
//public protocol Searchable: Hashable {
//
//    /// Term which will be used for the search
//    var searchTerm: String { get }
//}
//
//public extension Array where Element: Searchable {
//    func filter(by searchTerms: [String]) -> Self {
//        // all searchTerms must be machted, sorted by count to decrease the number of search elements
//        let sortedSearchTerms = searchTerms.sorted { $0.count > $1.count }
//
//        var currentElements = self
//        for searchTerm in sortedSearchTerms {
//
//            // skip all further iterations
//            if currentElements.isEmpty {
//                break
//            }
//
//            currentElements = currentElements.filter { $0.searchTerm.contains(searchTerm) }
//        }
//        return currentElements
//    }
//}
