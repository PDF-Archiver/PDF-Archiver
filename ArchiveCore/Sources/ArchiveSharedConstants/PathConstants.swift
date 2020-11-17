//
//  PathConstants.swift
//  
//
//  Created by Julian Kahnert on 18.10.20.
//

import Foundation

public enum PathConstants: Log {
    public static var iCloudDriveURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }
    private static let appGroupContainerURL: URL = {
        guard let tempImageURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.sharedContainerIdentifier) else {
            log.criticalAndAssert("AppGroup folder could not be found.")
            preconditionFailure("AppGroup folder could not be found.")
        }
        return tempImageURL
    }()

    public static let tempImageURL: URL = {
        let tempImageURL = appGroupContainerURL.appendingPathComponent("TempImages")
        createFolderIfNotExists(tempImageURL, name: "TempIamges")
        return tempImageURL
    }()

    public static let tempPdfURL: URL = {
        let tempImageURL = appGroupContainerURL.appendingPathComponent("TempPDFDocuments")
        createFolderIfNotExists(tempImageURL, name: "TempPDFDocuments")
        return tempImageURL
    }()

    public static var extensionTempPdfURL: URL {
        appGroupContainerURL
    }

    public static var appClipTempPdfURL: URL {
        tempPdfURL
    }

    private static func createFolderIfNotExists(_ folder: URL?, name: StaticString) {
        guard let folder = folder else {
            Self.log.info("Folder '\(name)' does not have an URL. - Skipping!")
            return
        }
        do {
            try FileManager.default.createFolderIfNotExists(folder)
        } catch {
            log.criticalAndAssert("Failed to create '\(name)' folder.", metadata: ["error": "\(error)"])
            preconditionFailure("Failed to create '\(name)' folder.")
        }
    }
}
