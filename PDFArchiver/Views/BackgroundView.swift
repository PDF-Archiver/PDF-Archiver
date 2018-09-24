//
//  MainView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class BackgroundView: NSView {

    override func layout() {
        super.layout()

        // set background color of the view
        self.wantsLayer = Constants.Layout.wantsLayer
        self.layer?.backgroundColor = NSColor(named: "MainViewBackground")!.cgColor
        self.layer?.cornerRadius = Constants.Layout.cornerRadius
    }
}
