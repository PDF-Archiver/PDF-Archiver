//
//  PathConstants.swift
//  
//
//  Created by Julian Kahnert on 18.10.20.
//

import Foundation

enum PathConstants: Log {
    private static let appGroupContainerURL: URL = {
        guard let tempImageURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.sharedContainerIdentifier) else {
            log.criticalAndAssert("AppGroup folder could not be found.")
            preconditionFailure("AppGroup folder could not be found.")
        }
        return tempImageURL
    }()

    static let tempDocumentURL: URL = {
        let tempImageURL = appGroupContainerURL.appendingPathComponent("TempDocuments")
        createFolderIfNotExists(tempImageURL, name: "TempDocuments")
        return tempImageURL
    }()

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
