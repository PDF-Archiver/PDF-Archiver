//
//  StorageType.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.08.25.
//

import Foundation

public nonisolated enum StorageType: Codable, Equatable, Sendable {
    case iCloudDrive
#if !os(macOS)
    case appContainer
#endif
    case local(URL)
}
