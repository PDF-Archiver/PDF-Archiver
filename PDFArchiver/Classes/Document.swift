//
//  Document.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 25.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import Quartz

//protocol DocumentDelegate {
//
//    func getDocumentDate() -> Date
//    func getDocumentDescription() -> String
//}

class Document: NSObject {
    // structure for PDF documents on disk
    var path: URL
    var already_done: Bool
    @objc var name: String?
    @objc var basepath: URL
    var pdf_filename: String?
    var pdf_date: Date?
    var pdf_description: String?
    var pdf_tags: [Tag]?
    
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
