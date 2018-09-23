//
//  WindowController.swift
//  Archiver
//
//  Created by Julian Kahnert on 05.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()

        // restore the window position, e.g. https://stackoverflow.com/a/49205940
        self.windowFrameAutosaveName = "MainWindowPosition"
    }

}
