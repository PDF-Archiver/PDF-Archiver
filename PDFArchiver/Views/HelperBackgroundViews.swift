//
//  MainView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import Foundation
import Quartz.PDFKit.PDFView

class BackgroundView: NSView {

    override func layout() {
        super.layout()

        // set background color of the view
        self.wantsLayer = Constants.Layout.wantsLayer
        self.layer?.cornerRadius = Constants.Layout.cornerRadius
        if self.identifier?.rawValue == "MainViewBackground" || self.identifier?.rawValue == "OnboardingBackgroundView" {
            self.layer?.backgroundColor = NSColor(named: "MainViewBackground")?.cgColor
        } else if self.identifier?.rawValue == "CustomViewBackground" {
            self.layer?.backgroundColor = NSColor(named: "CustomViewBackground")?.withAlphaComponent(0.1).cgColor
        }
    }
}

class PDFContentView: PDFView {

    override func layout() {
        super.layout()

        // set background color of the view
        guard let pdfContentViewBackgroundColor = NSColor(named: "PDFContentViewBackground") else { fatalError("PDFContentViewBackground color not found!") }
        self.backgroundColor = pdfContentViewBackgroundColor
        self.layer?.cornerRadius = Constants.Layout.cornerRadius
    }
}
