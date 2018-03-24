//
//  Preferences.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log

struct Preferences {
    let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "DataModel")
    fileprivate var _archivePath: URL?
    weak var delegate: TagsDelegate?
    var analyseOnlyLatestFolders: Bool = true
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
            self.save()
        }
    }

    init(delegate: TagsDelegate) {
        self.delegate = delegate
        self.load()
    }

    func save() {
        // save the archive path
        UserDefaults.standard.set(self._archivePath, forKey: "archivePath")

        // save the last tags (with count > 0)
        var tags: [String: Int] = [:]
        for tag in self.delegate?.getTagList() ?? Set<Tag>() {
            tags[tag.name] = tag.count
        }

        for (name, count) in tags where count < 1 {
            tags.removeValue(forKey: name)
        }
        UserDefaults.standard.set(tags, forKey: "tags")
    }

    mutating func load() {
        // load archive path
        self._archivePath = UserDefaults.standard.url(forKey: "archivePath")

        // load archive tags
        guard let tagsDict = (UserDefaults.standard.dictionary(forKey: "tags") ?? [:]) as? [String: Int] else { return }
        var newTagList = Set<Tag>()
        for (name, count) in tagsDict {
            newTagList.insert(Tag(name: name, count: count))
        }
        self.delegate!.setTagList(tagList: newTagList)
    }

    func getArchiveTags() {
        guard let path = self._archivePath else {
            os_log("No archive path selected, could not get old tags.", log: self.log, type: .error)
            return
        }

        // get year archive folders
        var folders = [URL]()
        do {
            let fileManager = FileManager.default
            folders = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: [.nameKey], options: .skipsHiddenFiles)
                // only show folders with year numbers
                .filter({ URL(fileURLWithPath: $0.path).lastPathComponent.prefix(2) == "20" || URL(fileURLWithPath: $0.path).lastPathComponent.prefix(2) == "19" })
                // sort folders by year
                .sorted(by: { $0.path > $1.path })

        } catch {
            os_log("An error occured while getting the archive year folders.")
        }

        // only use the latest two year folders by default
        if self.analyseOnlyLatestFolders {
            folders = Array(folders.prefix(2))
        }

        // get all PDF files from this year and the last years
        var files = [URL]()
        for folder in folders {
            files.append(contentsOf: getPDFs(url: folder))
        }

        // get tags and counts from filename
        var tags_raw: [String] = []
        for file in files {
            let matched = regex_matches(for: "_[a-z0-9]+", in: file.lastPathComponent) ?? []
            for tag in matched {
                tags_raw.append(String(tag.dropFirst()))
            }
        }

        let tagsDict = tags_raw.reduce(into: [:]) { counts, word in counts[word, default: 0] += 1 }
        var newTagList = Set<Tag>()
        for (name, count) in tagsDict {
            newTagList.insert(Tag(name: name, count: count))
        }
        self.delegate?.setTagList(tagList: newTagList)
    }

}
