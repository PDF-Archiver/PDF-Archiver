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
