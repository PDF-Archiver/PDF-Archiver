//
//  FileManager.swift
//  
//
//  Created by Julian Kahnert on 22.08.20.
//

import Foundation

extension FileManager {
    public func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = self.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    public func createFolderIfNotExists(_ folder: URL) throws {
        if !directoryExists(atPath: folder.path) {
            try createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
