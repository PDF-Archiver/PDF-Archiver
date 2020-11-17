//
//  PathManager.swift
//  
//
//  Created by Julian Kahnert on 16.11.20.
//

import ArchiveSharedConstants
import Foundation

fileprivate extension UserDefaults {
//    let bookmark = try newValue.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
//    UserDefaults.standard.set(bookmark, forKey: "observedPathWithSecurityScope")

    var archivePathType: PathManager.ArchivePathType? {
        get {
            try? getObject(forKey: .archivePathType)
        }
        set {
            do {
                try set(newValue, forKey: .archivePathType)
            } catch {
                log.errorAndAssert("Failed to set ArchivePathType.", metadata: ["error": "\(error)"])
            }
        }
    }
}

public final class PathManager: Log {

    public static let shared = PathManager()
    private static let userDefaults: UserDefaults = .appGroup

    public private(set) var archivePathType: ArchivePathType
    private let fileManager = FileManager.default

    private init() {
        archivePathType = PathManager.userDefaults.archivePathType ?? .iCloudDrive

        if let archiveURL = try? getArchiveUrl() {
            try? FileManager.default.createFolderIfNotExists(archiveURL)
        }

        if let untaggedURL = try? getUntaggedUrl() {
            try? FileManager.default.createFolderIfNotExists(untaggedURL)
        }
    }

    public func getArchiveUrl() throws -> URL {
        return try archivePathType.getArchiveUrl()
    }

    public func getUntaggedUrl() throws -> URL {
        try  getArchiveUrl().appendingPathComponent("untagged")
    }

    public func setArchiveUrl(with type: ArchivePathType) throws {
        if type == .iCloudDrive {
            guard fileManager.iCloudDriveURL != nil else { throw PathError.iCloudDriveNotFound }
        }

        let newArchiveUrl = try type.getArchiveUrl()
        let oldArchiveUrl = try archivePathType.getArchiveUrl()

        // TODO: test what happens when the new archive is not empty        
        try fileManager.moveItem(at: oldArchiveUrl, to: newArchiveUrl)

        Self.userDefaults.archivePathType = type
    }
}
