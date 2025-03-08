//
//  StatisticsViewModel.swift
//  
//
//  Created by Julian Kahnert on 27.12.20.
//

import OSLog
import SwiftData
import SwiftUI

@Observable
class StatisticsViewModel {

    private(set) var isInitialized = false
    private(set) var isLoading = true
    private(set) var topTags: [(String, Int)] = []
    private(set) var topYears: [(String, Int)] = []

    private(set) var taggedDocumentCount: Int = 0
    private(set) var untaggedDocumentCount: Int = 0

    func updateData(with documents: [Document]) {
        self.isLoading = true

        let taggedDocumentCount = documents.filter(\.isTagged).count
        self.taggedDocumentCount = taggedDocumentCount
        untaggedDocumentCount = documents.count - taggedDocumentCount

        let taggedDocuments = documents.filter(\.isTagged)
        let tmpTopTags = taggedDocuments
            .map(\.tags)
            .reduce(into: [String: Int]()) { (counts, documentTags) in
                for documentTag in documentTags {
                    counts[documentTag, default: 0] += 1
                }
            }
            .sorted { $0.value > $1.value }
            .prefix(3)
        self.topTags = Array(tmpTopTags)

        let tmpTopYears = taggedDocuments
            .map(\.url)
            .map { $0.deletingLastPathComponent().lastPathComponent }
            .reduce(into: [String: Int]()) { (counts, year) in
                counts[year, default: 0] += 1
            }
            .sorted { $0.value > $1.value }
            .prefix(3)
        self.topYears = Array(tmpTopYears)
        self.isLoading = false
        self.isInitialized = true
    }
}
