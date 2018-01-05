//
//  FileHandling.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Foundation
import Quartz

struct PDFDocument {
    // structure for PDF documents on disk
    
    var basepath: URL
    var name: String
    var date: Date?
    var description: String?
    var tags = Set<Character>()
    
    init(path: URL) {
        // create a filename and rename the document
        self.basepath = path.deletingLastPathComponent()
        self.name = path.lastPathComponent
        
        parse()
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

//func loadPDF(path: URL) {
//    
//    let url = NSBundle.mainBundle().URLForResource("myPDF", withExtension: "pdf")
//    let pdf = PDFDocument(URL: url)
//    pdf.pageCount() // number of pages in document
//    pdf.string() // entire text of document
//}

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
