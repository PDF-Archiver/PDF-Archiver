//
//  Preferences.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log

protocol PreferencesDelegate: class {
    func setTagList(tagDict: [String: Int])
    func getTagList() -> [String: Int]
}

struct Preferences {
    let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "DataModel")
    fileprivate var _archivePath: URL?
    weak var delegate: PreferencesDelegate?
    var archivePath: URL? {
        get {
            return self._archivePath
        }
        set {
            guard let newValue = newValue else { return }
            // save the security scope bookmark [https://stackoverflow.com/a/35863729]
            do {
                let bookmark = try newValue.bookmarkData(options: .securityScopeAllowOnlyReadAccess, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "securityScopeBookmark")
            } catch let error as NSError {
                os_log("Bookmark Write Fails: %@", log: self.log, type: .error, error as CVarArg)
            }
            
            self._archivePath = newValue
            self.getArchiveTags()
        }
    }

    init(delegate: PreferencesDelegate) {
        self.delegate = delegate
        self.load()
    }

    func save() {
        // save the archive path
        UserDefaults.standard.set(self._archivePath, forKey: "archivePath")

        // save the last tags (with count > 0)
        var tags = self.delegate?.getTagList() ?? [:]
        for (name, count) in tags where count < 1 {
            tags.removeValue(forKey: name)
        }
        UserDefaults.standard.set(tags, forKey: "tags")
    }

    mutating func load() {
        // load archive path
        self._archivePath = UserDefaults.standard.url(forKey: "archivePath")

        // load archive tags
        guard let tagsRaw = (UserDefaults.standard.dictionary(forKey: "tags") ?? [:]) as? [String: Int] else { return }
        self.delegate!.setTagList(tagDict: tagsRaw)
    }

    func getArchiveTags() {
        guard let path = self._archivePath else {
            os_log("No archive path selected, could not get old tags.", log: self.log, type: .error)
            return
        }
        // get all PDF files from this year and the last years
        let date = Date()
        let calendar = Calendar.current
        let path_year1 = path.appendingPathComponent(String(calendar.component(.year, from: date)),
                                                                  isDirectory: true)
        let path_year2 = path.appendingPathComponent(String(calendar.component(.year, from: date) - 1),
                                                                  isDirectory: true)
        var files = [URL]()
        files.append(contentsOf: getPDFs(url: path_year1))
        files.append(contentsOf: getPDFs(url: path_year2))

        // get tags and counts from filename
        var tags_raw: [String] = []
        for file in files {
            let matched = regex_matches(for: "_[a-z0-9]+", in: file.lastPathComponent) ?? []
            for tag in matched {
                tags_raw.append(String(tag.dropFirst()))
            }
        }

        let tags = tags_raw.reduce(into: [:]) { counts, word in counts[word, default: 0] += 1 }
        self.delegate?.setTagList(tagDict: tags)
    }

}
