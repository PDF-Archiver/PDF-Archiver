//
//  FileChange.swift
//
//  Created by Julian Kahnert on 17.08.20.
//

import DeepDiff
import Foundation

public enum FileChange {
    case added(Details)
    case updated(Details)
    case removed(URL)

    public struct Details: Equatable {
        let url: URL
        let filename: String
        let size: Int
        let downloadStatus: DownloadStatus

        init(url: URL, filename: String, size: Int, downloadStatus: FileChange.DownloadStatus) {
            self.url = url
            self.filename = filename
            self.size = size
            self.downloadStatus = downloadStatus
        }

        /// This should only be used while testing.
        init(fileUrl: URL, size: Int = 42, downloadStatus: FileChange.DownloadStatus = .local) {
            self.url = fileUrl
            self.filename = fileUrl.lastPathComponent
            self.size = size
            self.downloadStatus = downloadStatus
        }
    }
}

extension FileChange.Details: DiffAware {
    public typealias DiffId = URL

    public var diffId: URL {
        url
    }

    public static func compareContent(_ lhs: FileChange.Details, _ rhs: FileChange.Details) -> Bool {
        lhs == rhs
    }
}
