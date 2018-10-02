//
//  Tag.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 22.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

struct Tag {

    let name: String
    var count: Int
}

extension Tag: Hashable, CustomStringConvertible {
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        return lhs.name == rhs.name
    }
    var description: String { return "\(name) (\(count))" }
    var hashValue: Int { return name.hashValue }
}
