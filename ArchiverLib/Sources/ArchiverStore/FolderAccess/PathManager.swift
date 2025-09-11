//
//  PathManager.swift
//  
//
//  Created by Julian Kahnert on 16.11.20.
//

import ArchiverModels
import ComposableArchitecture
import Foundation
import Shared

private enum PathError: Error {
    case iCloudDriveNotFound
}

/// Get the "correct" path for the archive
///
/// Use the stored path if possible or choose an OS specific path otherwise.
extension Optional where Wrapped == StorageType {
    public func getPath() -> StorageType {
        if let self {
            return self
        } else if FileManager.default.isICloudDriveAvailable {
            return .iCloudDrive
        } else {
            #if os(macOS)
            return .local(FileManager.default.documentsDirectoryURL.appendingPathComponent("PDFArchiver"))
            #else
            return .appContainer
            #endif
        }
    }
}

@MainActor
final class PathManager: Log {

    static let shared = PathManager()

    @Shared(.archivePathType) private(set) var archivePathType: StorageType?

    private let fileManager = FileManager.default

    private init() {}

    func getArchiveUrl() throws -> URL {
        let archiveURL: URL
        if UserDefaults.standard.bool(forKey: "demoMode") {
            archiveURL = fileManager.temporaryDirectory
        } else {
            archiveURL = try archivePathType.getPath().getArchiveUrl()
        }
        try FileManager.default.createFolderIfNotExists(archiveURL)
        return archiveURL
    }

    func getUntaggedUrl() throws -> URL {
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
        let oldArchiveUrl = try archivePathType.getPath().getArchiveUrl()

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

        self.$archivePathType.withLock { $0 = type }

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
