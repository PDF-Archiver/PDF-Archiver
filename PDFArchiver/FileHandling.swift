//
//  FileHandling.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Foundation
import Quartz


func getOpenPanelFiles() -> [Document] {
    let openPanel = NSOpenPanel()
    openPanel.title = "Choose a .pdf file or a folder"
    openPanel.showsResizeIndicator = false
    openPanel.showsHiddenFiles = false
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = true
    openPanel.allowedFileTypes = ["pdf"]
    
    var pdf_documents: [Document] = []
    openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
        guard response == NSApplication.ModalResponse.OK else {
            return
        }
        // get new pdf documents
        for element in openPanel.urls {
            for pdf_path in getPDFs(url: element) {
                pdf_documents.append(Document(path: pdf_path))
            }
        }
    }
    return pdf_documents
}

func getPDFs(url: URL) -> Array<URL> {
    // function which gets an URL (file or folder) and returns the paths as URLs of the file or all PDF documents in this folder as an array
    let fileManager = FileManager.default
    if fileManager.isDirectory(url:url) ?? false {
        // folder found
        let enumerator = fileManager.enumerator(atPath: url.path)!
        var pdfURLs = [URL]()
        while let element = enumerator.nextObject() as? String, element.suffix(3).lowercased() == "pdf" {
            let pdf_url = URL(fileURLWithPath: url.path).appendingPathComponent(element)
            pdfURLs.append(pdf_url)
        }
        return pdfURLs
        
    } else if fileManager.isReadableFile(atPath: url.path) && url.pathExtension.lowercased() == "pdf" {
        // file found
        return [url]
    
    } else {
        // no file or directory found
        // TODO: this might throw an error
        return []
    }
}

extension FileManager {
    func isDirectory(url:URL) -> Bool? {
        var isDir: ObjCBool = ObjCBool(false)
        if fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        } else {
            return nil
        }
    }
}
