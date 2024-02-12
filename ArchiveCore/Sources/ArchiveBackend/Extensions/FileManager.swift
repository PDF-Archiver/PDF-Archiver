//
//  FileManager.swift
//  
//
//  Created by Julian Kahnert on 17.11.20.
//

import Foundation

extension FileManager {
    var iCloudDriveURL: URL? {
        if #available(iOS 16.0, *) {
            return url(forUbiquityContainerIdentifier: nil)?.appending(path: "Documents", directoryHint: .isDirectory)
        } else {
            return url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents", isDirectory: true)
        }
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
}
