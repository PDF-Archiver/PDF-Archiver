//
//  MainView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.09.18.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
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
            if #available(OSX 10.13, *) {
                self.layer?.backgroundColor = NSColor(named: "MainViewBackground")?.cgColor
            } else {
                self.layer?.backgroundColor = NSColor(calibratedRed: 0.980, green: 0.980, blue: 0.980, alpha: 1).cgColor
            }
        } else if self.identifier?.rawValue == "CustomViewBackground" {
            if #available(OSX 10.13, *) {
                self.layer?.backgroundColor = NSColor(named: "CustomViewBackground")?.withAlphaComponent(0.1).cgColor
            } else {
                self.layer?.backgroundColor = NSColor(calibratedRed: 0.131, green: 0.172, blue: 0.231, alpha: 1).cgColor
            }
        }
    }
}

class PDFContentView: PDFView {

    override func layout() {
        super.layout()

        // set background color of the view
        let tmpPdfContentViewBackgroundColor: NSColor?
        if #available(OSX 10.13, *) {
            tmpPdfContentViewBackgroundColor = NSColor(named: "PDFContentViewBackground")
        } else {
            tmpPdfContentViewBackgroundColor = NSColor(calibratedRed: 0.213, green: 0.242, blue: 0.286, alpha: 0.05)
        }
        guard let pdfContentViewBackgroundColor = tmpPdfContentViewBackgroundColor else { fatalError("PDFContentViewBackground color not found!") }
        self.backgroundColor = pdfContentViewBackgroundColor
        self.layer?.cornerRadius = Constants.Layout.cornerRadius
    }
}
