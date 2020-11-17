//
//  PathManager.swift
//  
//
//  Created by Julian Kahnert on 16.11.20.
//

import ArchiveSharedConstants
import Foundation

fileprivate extension UserDefaults {
    var archivePathType: PathManager.ArchivePathType {
        get {
            (try? getObject(forKey: .archivePathType)) ?? .iCloudDrive
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

    public private(set) var archiveURL: URL?
    public private(set) var untaggedURL: URL?

    private init() {
        archivePathType = PathManager.userDefaults.archivePathType
//        self.archiveURL = UserDefaults.appGroup.archiveURL ?? PathConstants.iCloudDriveURL
//        self.untaggedURL = UserDefaults.appGroup.untaggedURL ?? PathConstants.iCloudDriveURL?.appendingPathComponent("untagged")
//
//        PathConstants.createFolderIfNotExists(archiveURL, name: "archive")
//        PathConstants.createFolderIfNotExists(untaggedURL, name: "untagged")
    }

    public func getArchiveUrl() throws -> URL {
        return try archivePathType.getArchiveUrl()
    }

    public func setArchiveUrl(with type: ArchivePathType) throws {
        if type == .iCloudDrive {
            guard PathConstants.iCloudDriveURL != nil else { throw PathError.iCloudDriveNotFound }
        }

        let newArchiveUrl = try type.getArchiveUrl()
        let oldArchiveUrl = try archivePathType.getArchiveUrl()

        // TODO: test what happens when the new archive is not empty
        try fileManager.moveItem(at: oldArchiveUrl, to: newArchiveUrl)

        Self.userDefaults.archivePathType = type

    }
}

extension PathManager {
    public enum ArchivePathType: Equatable {
        case iCloudDrive
        case local(URL)

        func getArchiveUrl() throws -> URL {
            switch self {
                case .iCloudDrive:
                    guard let url = PathConstants.iCloudDriveURL else { throw PathError.iCloudDriveNotFound }
                    return url
                case .local(let url):
                    return url
            }
        }
    }
}

extension PathManager.ArchivePathType: Codable {
    enum CodingKeys: CodingKey {
        case iCloudDrive
        case local
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            let url =  try container.decode(URL.self, forKey: .local)
            self = .local(url)
        } catch {
            self = .iCloudDrive
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
            case .iCloudDrive:
                try container.encode("", forKey: .iCloudDrive)
            case .local(let url):
                try container.encode(url, forKey: .local)
        }
    }
}

extension PathManager {
    public enum PathError: Error {
        case archiveNotSelected
        case iCloudDriveNotFound
    }
}
