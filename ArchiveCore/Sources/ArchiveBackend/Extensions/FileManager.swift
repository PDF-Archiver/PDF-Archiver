//
//  FileManager.swift
//  
//
//  Created by Julian Kahnert on 17.11.20.
//

import Foundation

extension FileManager {
    var iCloudDriveURL: URL? {
        url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }

    #if !os(macOS)
    var appContainerURL: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    #endif

    #if os(macOS)
    var documentsDirectoryURL: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    #endif
    
    public func getFilesRecursive(at url: URL, with properties: [URLResourceKey]? = nil) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: properties) else { return [] }

        var files = [URL]()
        for case let file as URL in enumerator {
            guard !file.hasDirectoryPath else { continue }
            files.append(file)
        }
        return files
    }
}
