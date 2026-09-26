//
//  FileManager.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 16.06.24.
//

import ArchiverModels
import Foundation
import Logging

extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = self.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func createFolderIfNotExists(_ folder: URL) throws {
        if !directoryExists(at: folder) {
            Self.log.debug("Try to create folder", metadata: ["folder": "\(LogRedact.shape(folder))"])
            try createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            Self.log.debug("folder creation success", metadata: ["folder": "\(LogRedact.shape(folder))"])
        }
    }
}
