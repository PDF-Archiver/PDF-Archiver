//
//  StorageType.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.08.25.
//

public enum StorageType: String, CaseIterable, Sendable {
    case iCloudDrive
#if !os(macOS)
    case appContainer
#endif
    case local
}

extension StorageType: Identifiable {
    public var id: String {
        rawValue
    }
}
