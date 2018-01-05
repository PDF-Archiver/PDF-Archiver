//
//  FileHandling.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Foundation
import Quartz

class PDFDocument {
    
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

//func loadPDF(path: URL) {
//    
//    let url = NSBundle.mainBundle().URLForResource("myPDF", withExtension: "pdf")
//    let pdf = PDFDocument(URL: url)
//    pdf.pageCount() // number of pages in document
//    pdf.string() // entire text of document
//}

