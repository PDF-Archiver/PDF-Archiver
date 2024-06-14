//
//  PathManager+ArchivePathType.swift
//
//
//  Created by Julian Kahnert on 17.11.20.
//

import Foundation

extension PathManager {
    enum ArchivePathType: Equatable, Codable {
        case iCloudDrive
        #if !os(macOS)
        case appContainer
        #endif
        case local(URL)

        func getArchiveUrl() throws -> URL {
            switch self {
                case .iCloudDrive:
                    guard let url = FileManager.default.iCloudDriveURL else { throw PathError.iCloudDriveNotFound }
                    return url
                #if os(iOS)
                case .appContainer:
                    return FileManager.default.appContainerURL
                #endif
                case .local(let url):
                    return url
            }
        }

        var isFileBrowserCompatible: Bool {
            switch self {
                case .iCloudDrive:
                    return true
                #if !os(macOS)
                case .appContainer:
                    return false
                #endif
                case .local:
                    return true
            }
        }
    }
}
