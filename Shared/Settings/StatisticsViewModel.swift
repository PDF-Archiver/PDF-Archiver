//
//  StatisticsViewModel.swift
//  
//
//  Created by Julian Kahnert on 27.12.20.
//

import SwiftData
import SwiftUI
import OSLog

@Observable
class StatisticsViewModel {

    private(set) var isLoading = true
    private(set) var documents: [Document] = []
    private(set) var topTags: [(String, Int)] = []
    private(set) var topYears: [(String, Int)] = []

    var taggedDocumentCount: Int {
        documents.filter(\.isTagged)
            .count
    }

    var untaggedDocumentCount: Int {
        documents.filter(\.isTagged.flipped)
            .count
    }
    
    func updateData(with documents: [Document]) {
        self.isLoading = true
        self.documents = documents

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
    }
}
