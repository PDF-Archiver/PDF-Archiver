//
//  FileHandling.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Quartz

func getOpenPanel(_ title: String) -> NSOpenPanel {
    let openPanel = NSOpenPanel()
    openPanel.title = title
    openPanel.showsResizeIndicator = false
    openPanel.showsHiddenFiles = false
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.canCreateDirectories = true
    return openPanel
}

func getPDFs(url: URL) -> [URL] {
    // get URL (file or folder) and return paths of the file or all PDF documents in this folder
    let fileManager = FileManager.default
    if fileManager.isDirectory(url: url) ?? false {
        // folder found
        let enumerator = fileManager.enumerator(atPath: url.path)!
        var pdfURLs = [URL]()
        for element in enumerator {
            if let filename = element as? String,
                filename.suffix(3).lowercased() == "pdf" {
                let pdfUrl = URL(fileURLWithPath: url.path).appendingPathComponent(filename)
                pdfURLs.append(pdfUrl)
            }
        }
        return pdfURLs

    } else if fileManager.isReadableFile(atPath: url.path) && url.pathExtension.lowercased() == "pdf" {
        // file found
        return [url]

    } else {
        // no file or directory found
        return []
    }
}

extension FileManager {
    func isDirectory(url: URL) -> Bool? {
        var isDir: ObjCBool = ObjCBool(false)
        if fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        } else {
            return nil
        }
    }
}
