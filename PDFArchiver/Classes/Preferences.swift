//
//  Preferences.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

class Preferences {
    var _archivePath: URL?
    var tags: TagList?
    
    var archivePath: URL? {
        get {
            return self._archivePath
        }
        set {
            self._archivePath = newValue
            self.get_last_tags(path: newValue)
        }
    }
    init() {
        self.load()
    }
    
    func save() {
        UserDefaults.standard.set(self._archivePath, forKey: "archivePath")
        
        var tags: Dictionary<String, Int>
        for tag in self.tags!.list! {
            // TODO: generate Dictionary<String, Int> here!
            print(tag)
        }
        UserDefaults.standard.set(tags, forKey: "tags")
    }
    
    func load() {
        self._archivePath = UserDefaults.standard.url(forKey: "archivePath")
        
        if let tags_raw = UserDefaults.standard.dictionary(forKey: "tags") as? Dictionary<String, Int> {
            self.tags = TagList(tags: tags_raw)
        }
        
    }
    
    private func get_last_tags(path: URL?) {
        // get the archive path from the UserDefaults
        if (path == nil) {
            return
        }
        
        // get all PDF files from this year and the last years
        let date = Date()
        let calendar = Calendar.current
        let path_year1 = path!.appendingPathComponent(String(calendar.component(.year, from: date)),
                                                                  isDirectory: true)
        let path_year2 = path!.appendingPathComponent(String(calendar.component(.year, from: date) - 1),
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
        self.tags = TagList(tags: tags)

    }
    
}
