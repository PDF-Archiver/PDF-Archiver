//
//  DocumentViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import CoreGraphics
import Foundation

class DocumentViewModel: ObservableObject {

    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    @Published var specification: String
    @Published var formattedDate: String
    @Published var formattedSize: String
    @Published var sortedTags: [String]
    @Published var downloadStatus: CGFloat

    init(_ document: Document) {
        specification = document.specificationCapitalized
        if let date = document.date {
            formattedDate = DocumentViewModel.formatter.string(from: date)
        } else {
            formattedDate = ""
        }
        formattedSize = document.size ?? ""
        sortedTags = document.tags.sorted()
        switch document.downloadStatus {
        case .downloading(percentDownloaded: let value):
            downloadStatus = CGFloat(value)
        case .iCloudDrive:
            downloadStatus = 0
        case .local:
            downloadStatus = 1.0
        }
    }

    #if DEBUG
    /// This should only be used for testing!
    init(specification: String, formattedDate: String, formattedSize: String, sortedTags: [String], downloadStatus: CGFloat) {
        self.specification = specification
        self.formattedDate = formattedDate
        self.formattedSize = formattedSize
        self.sortedTags = sortedTags
        self.downloadStatus = downloadStatus
    }
    #endif
}
