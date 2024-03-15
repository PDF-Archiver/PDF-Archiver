//
//  FileManager.swift
//  
//
//  Created by Julian Kahnert on 17.11.20.
//

import Foundation

extension FileManager {
    var iCloudDriveURL: URL? {
        log.debug("Getting iCloudDriveURL")

        var foundUrl: URL?
        if #available(iOS 16, macOS 13, *) {
            foundUrl = url(forUbiquityContainerIdentifier: nil)?.appending(path: "Documents", directoryHint: .isDirectory)
        } else {
            foundUrl = url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents", isDirectory: true)
        }
        guard let foundUrl else { return nil }

        log.debug("Got iCloudDriveURL", metadata: ["iCloudDriveURL": "\(foundUrl)"])

        // try to fix the error:
        //        Error Domain=NSCocoaErrorDomain
        //        Code=513 "You don't have permission to save the file "Documents" in the folder
        //        "iCloud~de~JulianKahnert~PDFArchiver".
        //        {Error Domain=NSPOSIXErrorDomain
        //        Code=13 "Permission denied"}}
        guard FileManager.default.fileExists(at: foundUrl.deletingLastPathComponent()) else {
            log.debug("Folder did not exist")
            return nil
        }

        return foundUrl
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
