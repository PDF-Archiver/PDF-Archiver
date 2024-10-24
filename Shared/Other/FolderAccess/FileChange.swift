//
//  FileChange.swift
//
//  Created by Julian Kahnert on 17.08.20.
//

import DeepDiff
import Foundation

enum FileChange: Sendable {
    case added(Details)
    case updated(Details)
    case removed(URL)

    var url: URL {
       switch self {
       case .added(let details):
           return details.url
       case .updated(let details):
           return details.url
       case .removed(let url):
           return url
        }
    }

    struct Details: Equatable {
        let url: URL
        let filename: String
        let sizeInBytes: Double
        let downloadStatus: DownloadStatus

        init(url: URL, filename: String, sizeInBytes: Double, downloadStatus: FileChange.DownloadStatus) {
            self.url = url
            self.filename = filename
            self.sizeInBytes = sizeInBytes
            self.downloadStatus = downloadStatus
        }

        /// This should only be used while testing.
        init(fileUrl: URL, sizeInBytes: Double = 42, downloadStatus: FileChange.DownloadStatus = .local) {
            self.url = fileUrl
            self.filename = fileUrl.lastPathComponent
            self.sizeInBytes = sizeInBytes
            self.downloadStatus = downloadStatus
        }
    }
}

extension FileChange.Details: DiffAware {
    typealias DiffId = URL

    var diffId: URL {
        url
    }

    static func compareContent(_ lhs: FileChange.Details, _ rhs: FileChange.Details) -> Bool {
        lhs == rhs
    }
}
