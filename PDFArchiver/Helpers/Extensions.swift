//
//  Extensions.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 14.06.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

extension URL {
    var typeIdentifier: String? {
        return (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier
    }
}
