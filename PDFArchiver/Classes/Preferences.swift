//
//  Preferences.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

protocol PreferencesDelegate: class {
    func setTagList(tagDict: [String: Int])
    func getTagList() -> [String: Int]
}

struct Preferences {
    fileprivate var _archivePath: URL?
    weak var delegate: PreferencesDelegate?
    var archivePath: URL? {
        get {
            return self._archivePath
        }
        set {
            guard let newValue = newValue else { return }
            self._archivePath = newValue
            self.get_last_tags(path: newValue)
        }
    }

    init(delegate: PreferencesDelegate) {
        self.delegate = delegate
        self.load()
    }

    func save() {
        // save the archive path
        UserDefaults.standard.set(self._archivePath, forKey: "archivePath")

        // save the last tags
        let tags = self.delegate?.getTagList()
        UserDefaults.standard.set(tags, forKey: "tags")
    }

    mutating func load() {
        // load archive path
        self._archivePath = UserDefaults.standard.url(forKey: "archivePath")

        // load archive tags
        guard let tagsRaw = (UserDefaults.standard.dictionary(forKey: "tags") ?? [:]) as? [String: Int] else { return }
        self.delegate!.setTagList(tagDict: tagsRaw)
    }

    private func get_last_tags(path: URL) {
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
            let matched = regex_matches(for: "_[a-z0-9]+", in: file.lastPathComponent)
            tags_raw.append(contentsOf: matched.map({String($0.dropFirst())}))
        }

        let tags = tags_raw.reduce(into: [:]) { counts, word in counts[word, default: 0] += 1 }
        self.delegate?.setTagList(tagDict: tags)
    }

}
