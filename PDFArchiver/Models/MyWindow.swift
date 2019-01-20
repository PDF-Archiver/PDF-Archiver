//
//  MyWindow.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 06.02.18.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Cocoa

class MyWindow: NSWindow {
    override func recalculateKeyViewLoop() {
        // Remove. nextKeyView and makeFirstResponder seemed broken with this
    }
}
