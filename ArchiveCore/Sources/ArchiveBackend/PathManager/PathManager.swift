//
//  PathManager.swift
//  
//
//  Created by Julian Kahnert on 16.11.20.
//

import ArchiveSharedConstants
import Foundation

extension UserDefaults {
    var archivePathType: PathManager.ArchivePathType? {
        get {

            do {
                #if os(macOS)
                var staleBookmarkData = false
                if let type: PathManager.ArchivePathType = try? getObject(forKey: .archivePathType) {
                    return type
                } else if let bookmarkData = object(forKey: Names.archivePathType.rawValue) as? Data {
                    let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
                    if staleBookmarkData {
                        log.errorAndAssert("Found stale bookmark data.")
                    }
                    return .local(url)
                } else {
                    return nil
                }
                #else
                return try? getObject(forKey: .archivePathType)
                #endif
            } catch {
                log.errorAndAssert("Error while getting archive url.", metadata: ["error": "\(String(describing: error))"])
                NotificationCenter.default.postAlert(error)
                return nil
            }
        }
        set {
            do {
                #if os(macOS)
                switch newValue {
                    case .local(let url):
                        let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        set(bookmark, forKey: Names.archivePathType.rawValue)
                    default:
                        try setObject(newValue, forKey: .archivePathType)
                }
                #else
                try setObject(newValue, forKey: .archivePathType)
                #endif
            } catch {
                log.errorAndAssert("Failed to set ArchivePathType.", metadata: ["error": "\(error)"])
                NotificationCenter.default.postAlert(error)
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
            #if os(macOS)
            archivePathType = PathManager.userDefaults.archivePathType ?? .local(FileManager.default.documentsDirectoryURL.appendingPathComponent("PDFArchiver"))
            #else
            archivePathType = PathManager.userDefaults.archivePathType ?? .appContainer
            #endif
        }
    }

    public func getArchiveUrl() throws -> URL {
        let archiveURL: URL
        if UserDefaults.standard.isInDemoMode {
            archiveURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        } else {
            archiveURL = try archivePathType.getArchiveUrl()
        }
        try FileManager.default.createFolderIfNotExists(archiveURL)
        return archiveURL
    }

    public func getUntaggedUrl() throws -> URL {
        let untaggedURL = try getArchiveUrl().appendingPathComponent("untagged")
        try FileManager.default.createFolderIfNotExists(untaggedURL)
        return untaggedURL
    }

    public func setArchiveUrl(with type: ArchivePathType) throws {
        if type == .iCloudDrive {
            guard fileManager.iCloudDriveURL != nil else { throw PathError.iCloudDriveNotFound }
        }

        log.debug("Setting new archive type.", metadata: ["type": "\(type)"])

        let newArchiveUrl = try type.getArchiveUrl()
        let oldArchiveUrl = try archivePathType.getArchiveUrl()

        let contents = try fileManager.contentsOfDirectory(at: oldArchiveUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            .filter(\.hasDirectoryPath)
            .filter { folderUrl in
                folderUrl.lastPathComponent.isNumeric || folderUrl.lastPathComponent == "untagged"
            }

        for folder in contents {
            let destination = newArchiveUrl.appendingPathComponent(folder.lastPathComponent)

            if fileManager.directoryExists(at: destination) {
                try fileManager.moveContents(of: folder, to: destination)
            } else {
                try fileManager.moveItem(at: folder, to: destination)
            }
        }

        self.archivePathType = type
        Self.userDefaults.archivePathType = type
    }
}
