//
//  SearchToken.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

enum SearchToken: Hashable, Identifiable {
    case tag(String)
    case year(Int)

    var id: String { description }

    var description: String {
        switch self {
        case .tag(let tag):
            "tag: \(tag)"
        case .year(let year):
            "year: \(year)"
        }
    }

}
