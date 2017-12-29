//
//  ViewController.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var descriptionField: NSTextField!
    @IBOutlet weak var tagField: NSTextField!
    @IBOutlet weak var filenameField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
//    @IBAction func sayButtonClicked(_ sender: Any) {
//        var name = nameField.stringValue
//        if name.isEmpty {
//            name = "World"
//        }
//        let greeting = "Hello \(name)!"
//        helloLabel.stringValue = greeting
//    }
    
    @IBAction func nextButtonClicked(_ sender: Any) {
        let greeting = "NEXT"
        filenameField.stringValue = greeting
    }
    @IBAction func previousButtonClicked(_ sender: Any) {
        let greeting = "PREVIOUS"
        filenameField.stringValue = greeting
    }
    @IBAction func saveButtonClicked(_ sender: Any) {
    }
    
}

