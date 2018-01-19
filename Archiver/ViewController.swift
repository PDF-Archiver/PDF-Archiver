//
//  ViewController.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Cocoa
import Quartz

class ViewController: NSViewController {
    @IBOutlet weak var myDatePicker: NSDatePicker!
    @IBOutlet weak var descriptionField: NSTextField!
    @IBOutlet weak var tagField: NSTextField!
    @IBOutlet weak var filenameField: NSTextField!
    
    @IBOutlet weak var pdfPreview: PDFView!
    @IBOutlet var documentAC: NSArrayController!
    
    // outlets
    @IBAction func nextButtonClicked(_ sender: Any) {
        filenameField.stringValue = "NEXT"
    }
    
    @IBAction func previousButtonClicked(_ sender: Any) {
        filenameField.stringValue = "PREVIOUS"
    }
    
    @IBAction func saveButtonClicked(_ sender: Any) {
        // getting & setting the date/time value
        let myDate = myDatePicker.dateValue
        print(myDate)
    }
    
    @IBAction func browseFile(sender: AnyObject) {
        browse_files()
    }
    
    // other stuff
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}
