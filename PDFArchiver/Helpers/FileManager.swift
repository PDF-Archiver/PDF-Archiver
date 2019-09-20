//
//  FileManager.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 11.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

extension FileManager {
    func createFolderIfNotExists(_ folder: URL) throws {
        if !fileExists(atPath: folder.path, isDirectory: nil) {
            try createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
