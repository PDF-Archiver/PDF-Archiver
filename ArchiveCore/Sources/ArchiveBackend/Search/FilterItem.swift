//
//  FilterItem.swift
//  
//
//  Created by Julian Kahnert on 09.09.20.
//

import Foundation

public enum FilterItem: Identifiable, Equatable, Comparable {

    public static let cache = FilterCache()

    case year(Date)
    case yearMonth(Date)
    case yearMonthDay(Date)
    case tag(String)

    public var id: String {
        text
    }

    public var text: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        switch self {
            case .tag(let tagName):
                return tagName
            case .year(let date):
                formatter.setLocalizedDateFormatFromTemplate("yyyy")
                return formatter.string(from: date)
            case .yearMonth(let date):
                formatter.setLocalizedDateFormatFromTemplate("yyyyMM")
                return formatter.string(from: date)
            case .yearMonthDay(let date):
                formatter.setLocalizedDateFormatFromTemplate("yyyyMMdd")
                return formatter.string(from: date)
        }
    }

    public var imageSystemName: String {
        switch self {
            case .tag:
                return "tag"
            default:
                return "calendar"
        }
    }

    public var isTag: Bool {
        switch self {
            case .tag:
                return true
            case .year, .yearMonth, .yearMonthDay:
                return false
        }
    }
}

extension Array where Element == Document {
    public func filter(by filterItems: [FilterItem]) -> [Element] {
        var currentElements = self
        for filterItem in filterItems {
            currentElements = currentElements.filter(with: filterItem)
        }
        return currentElements
    }

    public func filter(with filterItem: FilterItem) -> [Element] {
        switch filterItem {
            case .tag(let name):
                let tagname = name.lowercased()
                return self.filter { $0.tags.contains(tagname) }
            case .year(let date):
                let dateString = FilterItem.cache.getTriple(for: date).year
                return self.filter { $0.filename.starts(with: dateString) }
            case .yearMonth(let date):
                let dateString = FilterItem.cache.getTriple(for: date).yearMonth
                return self.filter { $0.filename.starts(with: dateString) }
            case .yearMonthDay(let date):
                let dateString = FilterItem.cache.getTriple(for: date).yearMonthDay
                return self.filter { $0.filename.starts(with: dateString) }
        }
    }
}
