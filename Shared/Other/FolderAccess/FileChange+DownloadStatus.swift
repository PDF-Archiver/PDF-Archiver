//
//  FileChange+DownlaodStatus.swift
//  
//
//  Created by Julian Kahnert on 15.08.20.
//

extension FileChange {

    /// Download status of a file.
    ///
    /// - iCloudDrive: The file is currently only in iCloud Drive available.
    /// - downloading: The OS downloads the file currentyl.
    /// - local: The file is locally available.
    enum DownloadStatus: Equatable, Codable, CustomStringConvertible {

        case remote
        case downloading(percent: Double)
        case local

        var description: String {
            switch self {
                case .remote:
                    return "remote"
                case .downloading(percent: let percent):
                    return "downloading(\(percent)"
                case .local:
                    return "local"
            }
        }
    }
}
