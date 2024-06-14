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

//        enum CodingKeys: CodingKey {
//            case remote, downloading, local
//        }

//        init(from decoder: any Decoder) throws {
//            let container = try decoder.container(keyedBy: CodingKeys.self)
//
//            if true == (try? container.decode(Bool.self, forKey: .remote)) {
//                self = .remote
//            } else if let value = try? container.decode(Double.self, forKey: .downloading) {
//                self = .downloading(percent: value)
//            } else if true == (try? container.decode(Bool.self, forKey: .local)) {
//                self = .local
//            } else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Data doesn't match"))
//            }
//
//        }
//
//        func encode(to encoder: any Encoder) throws {
//            var container = encoder.container(keyedBy: CodingKeys.self)
//            switch self {
//            case .remote:
//                try container.encode(true, forKey: .remote)
//            case .local:
//                try container.encode(true, forKey: .local)
//            case .downloading(let percent):
//                try container.encode(percent, forKey: .downloading)
//            }
//        }

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
