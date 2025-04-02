//
//  FileManager.swift
//  
//
//  Created by Julian Kahnert on 22.08.20.
//

import Foundation

extension FileManager: Log {
    func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path)
    }

    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = self.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func createFolderIfNotExists(_ folder: URL) throws {
        if !directoryExists(at: folder) {
            log.debug("Try to create folder", metadata: ["folder": "\(folder.path)"])
            try createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            log.debug("folder creation success", metadata: ["folder": "\(folder.path)"])
        }
    }

    func moveContents(of sourceFolder: URL, to destinationFolder: URL) throws {
        guard directoryExists(at: sourceFolder),
              directoryExists(at: destinationFolder) else {
            preconditionFailure("Source/Destionation is no folder - this should not happen.")
        }

        let contents = try contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        for folder in contents {
            let destination = destinationFolder.appendingPathComponent(folder.lastPathComponent)

            if directoryExists(at: destination) {
                try moveContents(of: folder, to: destination)
            } else {
                try moveItem(at: folder, to: destination)
            }
        }
    }

    func getFilesRecursive(at url: URL, with properties: [URLResourceKey]? = nil) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: properties) else { return [] }

        var files = [URL]()
        for case let file as URL in enumerator {
            guard !file.hasDirectoryPath else { continue }
            files.append(file)
        }
        return files
    }
}
