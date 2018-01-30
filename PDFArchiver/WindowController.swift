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
        //1.
        if let window = window, let screen = window.screen {
            let offsetFromLeftOfScreen: CGFloat = 100
            let offsetFromTopOfScreen: CGFloat = 100
            //2.
            let screenRect = screen.visibleFrame
            //3.
            let newOriginY = screenRect.maxY - window.frame.height - offsetFromTopOfScreen
            //4.
            window.setFrameOrigin(NSPoint(x: offsetFromLeftOfScreen, y: newOriginY))
        }
    }

}


