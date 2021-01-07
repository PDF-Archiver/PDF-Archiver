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
}
