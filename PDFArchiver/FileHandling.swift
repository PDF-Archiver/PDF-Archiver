//
//  FileHandling.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Quartz

func getPDFs(url: URL) -> [URL] {
    // get URL (file or folder) and return paths of the file or all PDF documents in this folder
    let fileManager = FileManager.default
    if fileManager.isDirectory(url: url) ?? false {
        // folder found
        let enumerator = fileManager.enumerator(atPath: url.path)!
        var pdfURLs = [URL]()
        for element in enumerator where (element as! String).suffix(3).lowercased() == "pdf" {
            let pdf_url = URL(fileURLWithPath: url.path).appendingPathComponent(element as! String)
            pdfURLs.append(pdf_url)
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
