//
//  TagList.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 27.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

class TagList {
    // structure for available tags
    var list: [Tag]?
    
    init(tags: Dictionary<String, Int>) {
        self.list = []
        for (name, count) in tags {
            self.list?.append(Tag(name: name, count: count))
        }
    }
    
    func filter(prefix: String) -> [Tag] {
        var tags = [Tag]()
        for tag in self.list ?? [] {
            if tag.name.hasPrefix(prefix) {
                tags.append(tag)
            }
        }
        return tags

    }
    
    func sort(objs: [Tag], by key: String, ascending: Bool) -> [Tag] {
        if key == "name" {
            if ascending {
                return objs.sorted(by: { $0.name < $1.name })
            } else {
                return objs.sorted(by: { $0.name > $1.name })
            }
        } else if key == "count" {
            if ascending {
                return objs.sorted(by: { $0.count < $1.count })
            } else {
                return objs.sorted(by: { $0.count > $1.count })
            }
        } else {
            print("Wrong key '\(key)' selected. This should not happen!")
            return []
        }

    }
    
}
