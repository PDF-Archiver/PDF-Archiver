//
//  TagList.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 27.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

struct TagList {
    // structure for available tags
    var list: Set<Tag>

    init(tags: [String: Int]) {
        self.list = []
        for (name, count) in tags {
            self.list.insert(Tag(name: name, count: count))
        }
    }

    func filter(prefix: String) -> Set<Tag> {
        // TODO: fuzzy matching would be nice!
        let tags = self.list.filter { tag in
            return tag.name.hasPrefix(prefix)
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
