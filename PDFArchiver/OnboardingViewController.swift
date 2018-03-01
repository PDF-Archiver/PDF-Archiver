//
//  OnboardingViewController.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 28.02.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class OnboardingViewController: NSViewController {
    @IBOutlet weak var customView: NSView!
    @IBAction func closeButton(_ sender: NSButton) {
        self.dismiss(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do view setup here.
        UserDefaults.standard.set(true, forKey: "onboardingShown")
        
        // set background color of the view
        let layout = Layout()
//        self.view.wantsLayer = true
//        self.view.layer?.backgroundColor = layout.color3
//        self.view.layer?.cornerRadius = layout.cornerRadius
        
        self.customView.wantsLayer = true
        self.customView.layer?.backgroundColor = layout.color3
        self.customView.layer?.cornerRadius = layout.cornerRadius
    }
}
