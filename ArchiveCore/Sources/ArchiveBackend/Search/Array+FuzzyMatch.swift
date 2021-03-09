//
//  Array+FuzzyMatch.swift
//  
//
//  Created by Julian Kahnert on 25.08.20.
//

import Foundation

public typealias Term = [UInt8]
public protocol Searchitem: Equatable {
    var term: Term { get }
}

extension Term: Searchitem {
    public var term: Term {
        self
    }
}

extension String: Searchitem {
    public var term: Term {
        utf8.map { UInt8($0) }
    }
}

extension Array where Element: Searchitem, Element: Comparable {
    public func fuzzyMatchSorted(by searchTerms: [String]) -> Self {
        guard !searchTerms.isEmpty else { return self.sorted() }

        // all searchTerms must be matched, sorted by count to decrease the number of search elements
        let sortedSearchTerms = searchTerms
            .map { $0.lowercased() }
            .sorted { $0.count > $1.count }

        var currentElements = self
        for searchTerm in sortedSearchTerms {

            // skip all further iterations
            if currentElements.isEmpty {
                break
            }

            currentElements = currentElements.fuzzyMatchSorted(searchTerm)
        }
        return currentElements
    }

    public func fuzzyMatchSorted(_ needle: String) -> [Element] {
        fuzzyMatch(needle)
            .sorted { $0.score < $1.score }
            .map(\.item)
    }
}

extension Array where Element: Searchitem {
    public func fuzzyMatch(_ needle: String) -> [(item: Element, score: Int)] {
        let needleUtf8View = [UInt8](needle.utf8)
        var result: [(item: Element, score: Int)] = []
        let resultQueue = DispatchQueue(label: "result")
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let chunkSize = count / cores
        DispatchQueue.concurrentPerform(iterations: cores) { idx in
            let start = idx * chunkSize
            let end = idx == cores - 1 ? endIndex : start + chunkSize
            let chunk: [(Element, Int)] = self[start..<end].compactMap { element in
                guard let match = element.term.fuzzyMatch3(needleUtf8View) else { return nil }
                return (element, match.score)
            }
            resultQueue.sync {
                result.append(contentsOf: chunk)
            }
        }
        return result
    }
}

extension Array where Element: Equatable {
    // swiftlint:disable:next cyclomatic_complexity
    private func fuzzyMatch3(_ needle: [Element]) -> (score: Int, matrix: Matrix<Int?>)? {
        guard needle.count <= count else { return nil }
        var matrix = Matrix<Int?>(width: self.count, height: needle.count, initialValue: nil)
        if needle.isEmpty { return (score: 0, matrix: matrix) }
        var prevMatchIdx: Int = -1
        for row in 0..<needle.count {
            let needleChar = needle[row]
            var firstMatchIdx: Int?
            let remainderLength = needle.count - row - 1
            for column in (prevMatchIdx + 1)..<(count - remainderLength) {
                let char = self[column]
                guard needleChar == char else {
                    continue
                }
                if firstMatchIdx == nil {
                    firstMatchIdx = column
                }
                var score = 1
                if row > 0 {
                    var maxPrevious = Int.min
                    for prevColumn in prevMatchIdx..<column {
                        guard let item = matrix[prevColumn, row - 1] else { continue }
                        let gapPenalty = (column - prevColumn) - 1
                        maxPrevious = Swift.max(maxPrevious, item - gapPenalty)
                    }
                    score += maxPrevious
                }
                matrix[column, row] = score
            }
            guard let firstIx = firstMatchIdx else { return nil }
            prevMatchIdx = firstIx
        }
        guard let score = matrix[row: needle.count - 1].compactMap({ $0 }).max() else {
            return  nil
        }
        return (score, matrix)
    }
}
