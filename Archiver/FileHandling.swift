//
//  FileHandling.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Foundation
import Quartz

class Document: NSObject {
    // structure for PDF documents on disk
    var path: URL
    var already_done: Bool
    @objc var name: String?
    @objc var basepath: URL
    var pdf_filename: String?
    var pdf_date: Date?
    var pdf_description: String?
    var pdf_tags = Set<Character>()
    
    init(path: URL) {
        self.path = path
        // create a filename and rename the document
        self.basepath = path.deletingLastPathComponent()
        self.name = path.lastPathComponent
        self.already_done = false
    }
    
    func rename() {
        // create a filename and rename the document
        print("RENAMING FUNCTION")
    }
    
    func parse(){
        // parse the existing name and set some properties
        print("parse all the things")
    }
    
}

func browse_files() {
    let openPanel = NSOpenPanel()
    openPanel.title = "Choose a .pdf file or a folder"
    openPanel.showsResizeIndicator = false
    openPanel.showsHiddenFiles = false
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = true
    openPanel.allowedFileTypes = ["pdf"]
    
    openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
        guard response == NSApplication.ModalResponse.OK else {
            return
        }
        // clear old objects
        let controller = NSApplication.shared.mainWindow?.windowController?.contentViewController as! ViewController
        controller.documentAC.content = nil
        
        // add new objects
        for element in openPanel.urls {
            for pdf_path in getPDFs(url: element) {
                controller.documentAC.addObject(Document(path: pdf_path))
            }
        }
    }
}

func getPDFs(url: URL) -> Array<URL> {
    // function which gets an URL (file or folder) and returns the paths as URLs of the file or all PDF documents in this folder as an array
    
    let fileManager = FileManager.default
    if fileManager.isDirectory(url:url) ?? false {
        // folder found
        let enumerator: FileManager.DirectoryEnumerator = fileManager.enumerator(atPath: url.path)!
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
