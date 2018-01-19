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
    @IBOutlet weak var pdfview: PDFView!
    
    @IBOutlet weak var myDatePicker: NSDatePicker!
    @IBOutlet weak var descriptionField: NSTextField!
    @IBOutlet weak var tagField: NSTextField!
    @IBOutlet weak var filenameField: NSTextField!
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        // TODO: example code
        let url = URL(fileURLWithPath: "/Users/juka/Downloads/test.pdf")
        pdfview.document = PDFDocument(url: url)
        pdfview.displayMode = PDFDisplayMode.singlePageContinuous
//        pdfview.displayMode = PDFDisplayMode.singlePage
        pdfview.autoScales = false
        
    }
    

}
