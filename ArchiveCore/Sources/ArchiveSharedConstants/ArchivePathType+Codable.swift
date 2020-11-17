//
//  ArchivePathType+Codable.swift
//  
//
//  Created by Julian Kahnert on 16.11.20.
//

//import Foundation
//
//extension ArchivePathType: Codable {
//    enum CodingKeys: CodingKey {
//        case iCloudDrive
//        case local
//    }
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        do {
//            let url =  try container.decode(URL.self, forKey: .local)
//            self = .local(url)
//        } catch {
//            self = .iCloudDrive
//        }
//    }
//    
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//
//        switch self {
//            case .iCloudDrive:
//                try container.encode("", forKey: .iCloudDrive)
//            case .local(let url):
//                try container.encode(url, forKey: .local)
//        }
//    }
//}
