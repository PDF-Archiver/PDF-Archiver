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
    fileprivate var _observedPath: URL?
    weak var delegate: TagsDelegate?
    var analyseOnlyLatestFolders: Bool = true
    var observedPath: URL? {
        // ATTENTION: only set observed path, after an OpenPanel dialog
        get {
            return self._observedPath
        }
        set {
            guard let newValue = newValue else { return }
            // save the security scope bookmark [https://stackoverflow.com/a/35863729]
            do {
                let bookmark = try newValue.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "observedPathWithSecurityScope")
            } catch let error as NSError {
                os_log("Observed path bookmark Write Fails: %@", log: self.log, type: .error, error as CVarArg)
            }

            self._observedPath = newValue
        }
    }
    var archivePath: URL? {
        // ATTENTION: only set archive path, after an OpenPanel dialog
        get {
            return self._archivePath
        }
        set {
            guard let newValue = newValue else { return }
            // save the security scope bookmark [https://stackoverflow.com/a/35863729]
            do {
                let bookmark = try newValue.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "securityScopeBookmark")
            } catch let error as NSError {
                os_log("Bookmark Write Fails: %@", log: self.log, type: .error, error as CVarArg)
            }

            self._archivePath = newValue
            self.getArchiveTags()
        }
    }

    func save() {
        // there is no need to save the archive/observed path here - see the setter of the variable

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
        // load the archive path via the security scope bookmark [https://stackoverflow.com/a/35863729]
        if let bookmarkData = UserDefaults.standard.object(forKey: "securityScopeBookmark") as? Data {
            do {
                var staleBookmarkData = false
                self._archivePath = try URL.init(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
                if staleBookmarkData {
                    os_log("Stale bookmark data!", log: self.log, type: .fault)
                }
                let result = self._archivePath?.startAccessingSecurityScopedResource()
                if !(result ?? false) {
                    os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
                }
            } catch let error as NSError {
                os_log("Bookmark Access failed: %@", log: self.log, type: .error, error.description as CVarArg)
            }
        }

        // load the observed path via the security scope bookmark [https://stackoverflow.com/a/35863729]
        if let bookmarkData = UserDefaults.standard.object(forKey: "observedPathWithSecurityScope") as? Data {
            do {
                var staleBookmarkData = false
                self._observedPath = try URL.init(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
                if staleBookmarkData {
                    os_log("Stale bookmark data!", log: self.log, type: .fault)
                }
                let result = self._observedPath?.startAccessingSecurityScopedResource()
                if !(result ?? false) {
                    os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
                }
            } catch let error as NSError {
                os_log("Bookmark Access failed: %@", log: self.log, type: .error, error.description as CVarArg)
            }
        }

        // load archive tags
        guard let tagsDict = (UserDefaults.standard.dictionary(forKey: "tags") ?? [:]) as? [String: Int] else { return }
        var newTagList = Set<Tag>()
        for (name, count) in tagsDict {
            newTagList.insert(Tag(name: name, count: count))
        }
        self.delegate?.setTagList(tagList: newTagList)

        // get the security scope bookmark of the observed path
        if let bookmarkData = UserDefaults.standard.object(forKey: "securityScopeBookmarkObservedPath") as? Data {
            do {
                let observedPath = try NSURL.init(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: nil)
                observedPath.startAccessingSecurityScopedResource()
            } catch let error as NSError {
                os_log("Bookmark Access failed: %@", log: self.log, type: .error, error.description as CVarArg)
            }
        }
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
        var tagsRaw: [String] = []
        for file in files {
            let matched = regex_matches(for: "_[a-z0-9]+", in: file.lastPathComponent) ?? []
            for tag in matched {
                tagsRaw.append(String(tag.dropFirst()))
            }
        }

        let tagsDict = tagsRaw.reduce(into: [:]) { counts, word in counts[word, default: 0] += 1 }
        var newTagList = Set<Tag>()
        for (name, count) in tagsDict {
            newTagList.insert(Tag(name: name, count: count))
        }
        self.delegate?.setTagList(tagList: newTagList)
    }

}
