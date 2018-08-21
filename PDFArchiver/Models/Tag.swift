//
//  Tag.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 22.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

class Tag: NSObject {
    // structure for available tags
    @objc private(set) var name: String
    @objc var count: Int

    init(name: String, count: Int) {
        self.name = name
        self.count = count
    }

    // MARK: - Other Stuff
    override var description: String {
        return "<Tag \(self.name): \(self.count)>"
    }
}
