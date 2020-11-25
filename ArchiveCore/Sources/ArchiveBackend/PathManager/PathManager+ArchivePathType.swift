//
//  PathManager+ArchivePathType.swift
//  
//
//  Created by Julian Kahnert on 17.11.20.
//

import Foundation

extension PathManager {
    public enum ArchivePathType: Equatable {
        case iCloudDrive
        case appContainer
        #if os(macOS)
        case local(URL)
        #endif

        func getArchiveUrl() throws -> URL {
            switch self {
                case .iCloudDrive:
                    guard let url = FileManager.default.iCloudDriveURL else { throw PathError.iCloudDriveNotFound }
                    return url
                case .appContainer:
                    return FileManager.default.appContainerURL
                #if os(macOS)
                case .local(let url):
                    return url
                #endif
            }
        }
    }
}

extension PathManager.ArchivePathType: Codable {
    enum CodingKeys: CodingKey {
        case iCloudDrive
        case appContainer
        #if os(macOS)
        case local
        #endif
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = container.allKeys.first
        switch key {
            case .iCloudDrive:
                self = .iCloudDrive
            case .appContainer:
                self = .appContainer
            #if os(macOS)
            case .local:
                let url =  try container.decode(URL.self, forKey: .local)
                self = .local(url)
            #endif
            case .none:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Unabled to decode enum."
                    )
                )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .iCloudDrive:
                try container.encode("", forKey: .iCloudDrive)
            case .appContainer:
                try container.encode("", forKey: .appContainer)
            #if os(macOS)
            case .local(let url):
                try container.encode(url, forKey: .local)
            #endif
        }
    }
}
