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
