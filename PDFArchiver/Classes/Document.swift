//
//  Document.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 25.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

class Document: NSObject {
    // structure for PDF documents on disk
    var path: URL
    @objc var name: String?
    var pdf_filename: String = ""
    var pdf_date: Date = Date()
    var pdf_description: String? {
        get {
            return self._pdf_description
        }
        set {
            if var raw = newValue {
                // TODO: we could use a CocoaPod here...
                raw = raw.lowercased()
                raw = raw.replacingOccurrences(of: " ", with: "-")
                raw = raw.replacingOccurrences(of: "[:;.,!?/\\^+<>]", with: "", options: .regularExpression, range: nil)
                // german umlaute
                raw = raw.replacingOccurrences(of: "ä", with: "ae")
                raw = raw.replacingOccurrences(of: "ö", with: "oe")
                raw = raw.replacingOccurrences(of: "ü", with: "ue")
                raw = raw.replacingOccurrences(of: "ß", with: "ss")
                
                self._pdf_description = raw
            }
        }
    }
    var pdf_tags: [Tag] = [Tag]()
    fileprivate var _pdf_description: String? = ""
    
    init(path: URL) {
        self.path = path
        // create a filename and rename the document
        self.name = path.lastPathComponent
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
