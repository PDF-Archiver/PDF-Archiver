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
    var pdf_filename: String?
    var pdf_date: Date?
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
    var pdf_tags: [Tag]?
    fileprivate var _pdf_description: String?
    
    init(path: URL) {
        self.path = path
        // create a filename and rename the document
        self.name = path.lastPathComponent
    }
    
    func rename() -> Bool{
        // create a filename and rename the document
        if let date = self.pdf_date,
           let description = self.pdf_description,
           let tags = self.pdf_tags {
            print(date)
            print(description)
            print(tags)
            
            // TODO: implement parsing here
            print("Congratulations!!!")
            return true
            
        } else {
            print("Renaming not possible! Doublecheck the document fields.")
            return false
        }
    }
}
