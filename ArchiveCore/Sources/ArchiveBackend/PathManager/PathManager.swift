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
                var staleBookmarkData = false
                if let type: PathManager.ArchivePathType = try? getObject(forKey: .archivePathType) {
                    return type
                } else if let bookmarkData = object(forKey: Names.archivePathType.rawValue) as? Data {
#if os(macOS)
                    let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
                    if staleBookmarkData {
                        set(nil, forKey: Names.archivePathType.rawValue)
                        log.errorAndAssert("Found stale bookmark data.")
                        return nil
                    }
                    return .local(url)
#else
					let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &staleBookmarkData)
					guard !staleBookmarkData else {
						// Handle stale data here.
						log.errorAndAssert("Error while getting archive url. Stale bookmark data.")
						return nil
					}
					return .local(url)
#endif
                } else {
                    return nil
                }
            } catch {
                set(nil, forKey: Names.archivePathType.rawValue)
                log.errorAndAssert("Error while getting archive url.", metadata: ["error": "\(String(describing: error))"])
                NotificationCenter.default.postAlert(error)
                return nil
            }
        }

        set {
            do {
                switch newValue {
                    case .local(let url):
#if os(macOS)
                        let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        set(bookmark, forKey: Names.archivePathType.rawValue)
#else
						// Securely access the URL to save a bookmark
						guard url.startAccessingSecurityScopedResource() else {
							// Handle the failure here.
							return
						}
						// We have to stop accessing the resource no matter what
						defer { url.stopAccessingSecurityScopedResource() }
						do {
							// Make sure the bookmark is minimal!
							let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
							set(bookmark, forKey: Names.archivePathType.rawValue)
						} catch {
							print("Bookmark error \(error)")
						}
#endif
                    default:
                        try setObject(newValue, forKey: .archivePathType)
                }
            } catch {
                set(nil, forKey: Names.archivePathType.rawValue)
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

        var moveError: Error?
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
        Self.userDefaults.archivePathType = type

        if let moveError = moveError {
            throw moveError
        }
    }
}
