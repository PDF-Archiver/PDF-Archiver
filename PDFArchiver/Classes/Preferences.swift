//
//  Preferences.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

struct Preferences {
    var archivePath: URL? {
        get {
            return UserDefaults.standard.url(forKey: "archivePath")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "archivePath")
        }
    }
    
    var tags: Dictionary<String, Int>? {
        get {
            return UserDefaults.standard.dictionary(forKey: "tags") as? Dictionary<String, Int>
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "tags")
        }
    }
    
    mutating func get_last_tags() {
        // get the archive path from the UserDefaults
        if (self.archivePath == nil) {
            return
        }
        
        // get all PDF files from this year and the last years
        let date = Date()
        let calendar = Calendar.current
        let path_year1 = self.archivePath!.appendingPathComponent(String(calendar.component(.year, from: date)),
                                                             isDirectory: true)
        let path_year2 = self.archivePath!.appendingPathComponent(String(calendar.component(.year, from: date) - 1),
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
        self.tags = tags_raw.reduce(into: [:]) { counts, word in counts[word, default: 0] += 1 }
    }

}
