//
//  PathManager.swift
//  
//
//  Created by Julian Kahnert on 16.11.20.
//

import ArchiverModels
import Foundation
import Shared

private enum PathError: Error {
    case iCloudDriveNotFound
}

@MainActor
public final class PathManager: Log {

    public static let shared = PathManager()

    private(set) var archivePathType: StorageType
    private let fileManager = FileManager.default

    private init() {
        let iCloudDriveAvailable = FileManager.default.iCloudDriveURL != nil
        if iCloudDriveAvailable {
            archivePathType = UserDefaults.archivePathType ?? .iCloudDrive
        } else {
            #if os(macOS)
            archivePathType = UserDefaults.archivePathType ?? .local(FileManager.default.documentsDirectoryURL.appendingPathComponent("PDFArchiver"))
            #else
            archivePathType = UserDefaults.archivePathType ?? .appContainer
            #endif
        }
    }

    func getArchiveUrl() throws -> URL {
        let archiveURL: URL
        if UserDefaults.isInDemoMode {
            archiveURL = fileManager.temporaryDirectory
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

    func setArchiveUrl(with type: StorageType) throws {
        if type == .iCloudDrive {
            guard fileManager.iCloudDriveURL != nil else { throw PathError.iCloudDriveNotFound }
        }

        log.debug("Setting new archive type.", metadata: ["type": "\(type)"])

        let newArchiveUrl = try type.getArchiveUrl()
        let oldArchiveUrl = try archivePathType.getArchiveUrl()

        guard newArchiveUrl != oldArchiveUrl else {
            log.errorAndAssert("Old and new archive url should be different", metadata: ["newArchiveUrl": "\(newArchiveUrl)"])
            return
        }

        let contents = try fileManager.contentsOfDirectory(at: oldArchiveUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            .filter(\.hasDirectoryPath)
            .filter { folderUrl in
                folderUrl.lastPathComponent.isNumeric || folderUrl.lastPathComponent == "untagged"
            }

        var moveError: (any Error)?
        for folder in contents {
            let destination = newArchiveUrl.appendingPathComponent(folder.lastPathComponent)

            do {
                if fileManager.directoryExists(at: destination) {
                    try fileManager.moveContents(of: folder, to: destination)
                } else {
                    try fileManager.moveItem(at: folder, to: destination)
                }
            } catch {
                // we do not want to abort the move process - save error and show it later
                moveError = error
            }
        }

        self.archivePathType = type
        UserDefaults.archivePathType = type

        if let moveError = moveError {
            throw moveError
        }
    }
}

extension StorageType {
    func getArchiveUrl() throws -> URL {
        switch self {
        case .iCloudDrive:
            guard let url = FileManager.default.iCloudDriveURL else {
                throw PathError.iCloudDriveNotFound
            }
            return url
#if os(iOS)
        case .appContainer:
            return FileManager.default.appContainerURL
#endif
        case .local(let url):
            return url
        }
    }
}
