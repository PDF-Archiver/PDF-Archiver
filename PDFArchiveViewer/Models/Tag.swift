//
//  Tag.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 22.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

class Tag {

    let name: String
    var count: Int

    init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

extension Tag: Hashable, CustomStringConvertible {
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        return lhs.name == rhs.name
    }
    var description: String { return "\(self.name) (\(self.count))" }
    var hashValue: Int { return self.name.hashValue }
}
