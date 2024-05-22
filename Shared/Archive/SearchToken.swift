//
//  SearchToken.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

enum SearchToken: Hashable, Identifiable {
    case term(String)
    case tag(String)
    case year(Int)
    
    var id: String { description }
    
    var isTerm: Bool {
        switch self {
        case .term(_):
            return true
        default:
            return false
        }
    }
    
    var isYear: Bool {
        switch self {
        case .year(_):
            return true
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .term(let term):
            "term: \(term)"
        case .tag(let tag):
            "tag: \(tag)"
        case .year(let year):
            "year: \(year)"
        }
    }

    var term: String {
        switch self {
        case .term(let term):
            term
        case .tag(let tag):
            tag
        case .year(let year):
            "\(year)"
        }
    }
}
