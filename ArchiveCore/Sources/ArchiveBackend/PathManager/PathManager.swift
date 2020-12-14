//
//  PathManager.swift
//  
//
//  Created by Julian Kahnert on 16.11.20.
//

import ArchiveSharedConstants
import Foundation

extension UserDefaults {
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
        let iCloudDriveAvailable = FileManager.default.iCloudDriveURL != nil
        if iCloudDriveAvailable {
            archivePathType = PathManager.userDefaults.archivePathType ?? .iCloudDrive
        } else {
            archivePathType = PathManager.userDefaults.archivePathType ?? .appContainer
        }
    }

    public func getArchiveUrl() throws -> URL {
        let archiveURL = try archivePathType.getArchiveUrl()
        try FileManager.default.createFolderIfNotExists(archiveURL)
        return archiveURL
    }

    public func getUntaggedUrl() throws -> URL {
        let untaggedURL = try  getArchiveUrl().appendingPathComponent("untagged")
        try FileManager.default.createFolderIfNotExists(untaggedURL)
        return untaggedURL
    }

    public func setArchiveUrl(with type: ArchivePathType) throws {
        if type == .iCloudDrive {
            guard fileManager.iCloudDriveURL != nil else { throw PathError.iCloudDriveNotFound }
        }

        let newArchiveUrl = try type.getArchiveUrl()
        let oldArchiveUrl = try archivePathType.getArchiveUrl()

        let contents = try fileManager.contentsOfDirectory(at: oldArchiveUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            .filter(\.hasDirectoryPath)
            .filter { folderUrl in
                folderUrl.lastPathComponent.isNumeric || folderUrl.lastPathComponent == "untagged"
            }

        for file in contents {
            let destination = newArchiveUrl.appendingPathComponent(file.lastPathComponent)
            try fileManager.moveItem(at: file, to: destination)
        }

        self.archivePathType = type
        Self.userDefaults.archivePathType = type
    }
}
