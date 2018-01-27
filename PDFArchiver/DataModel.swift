//
//  DataModel.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import Cocoa

// Diese Klasse repräsentiert die Datenstruktur die du hast, mit allen möglichen Berechnungen etc. bevor Werte zum ViewController gegeben werden.

class DataModel {
    
    // Die Variable, in der der "Teil des Viewcontrollers" gespeichert wird
    // Muss optional sein, da im Initialzer kein delegate übergeben wird
    var delegate: DocumentProtocol?
    
    var prefs: Preferences
    var documents: [Document]?
    var tags: TagList?
    var old_tags: [Tag]?
    
    init() {
        self.prefs = Preferences()
        
    }
    
    func doSomeStuffWithDelegate() {
        // Hier erfolgt der Zugriff auf den Teil des ViewControllers
        let docDate: Date = (delegate?.getDocumentDate())!
        let docDescription: String = (delegate?.getDocumentDescription())!
        
        print(docDate)
        print(docDescription)

    }
    
    func get_last_tags() {
        // get the archive path from the UserDefaults
        if (self.prefs.archivePath == nil) {
            return
        }
        
        // get all PDF files from this year and the last years
        let date = Date()
        let calendar = Calendar.current
        let path_year1 = self.prefs.archivePath!.appendingPathComponent(String(calendar.component(.year, from: date)),
                                                                  isDirectory: true)
        let path_year2 = self.prefs.archivePath!.appendingPathComponent(String(calendar.component(.year, from: date) - 1),
                                                                  isDirectory: true)
        var files = [URL]()
        files.append(contentsOf: getPDFs(url: path_year1))
        files.append(contentsOf: getPDFs(url: path_year2))
        
        // get tags and counts from filename
        var tags_raw: Array<String> = []
        for file in files {
            let matched = regex_matches(for: "_[a-z0-9]+", in: file.lastPathComponent)
            tags_raw.append(contentsOf: matched.map({String($0.dropFirst())}))
        }
        let tags = tags_raw.reduce(into: [:]) { counts, word in counts[word, default: 0] += 1 }
        print(tags)
    }
}
