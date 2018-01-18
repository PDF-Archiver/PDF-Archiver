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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let pdf_path = URL(fileURLWithPath: "~/Downloads/test.pdf")
        let test = PDFDocument(path: pdf_path)
        self.documentAC.addObject(test)
        
    }
    
//    override var representedObject: Any? {
//        didSet {
//            if let url = representedObject as? URL {
////                directory = Directory(folderURL: url)
//            }
//        }
//    }
    
    // button callbacks
    @IBAction func nextButtonClicked(_ sender: Any) {
        let greeting = "NEXT"
        filenameField.stringValue = greeting
    }
    @IBAction func previousButtonClicked(_ sender: Any) {
        let greeting = "PREVIOUS"
        filenameField.stringValue = greeting
    }
    @IBAction func saveButtonClicked(_ sender: Any) {
        // getting & setting the date/time value
        let myDate = myDatePicker.dateValue
        print(myDate)
    }
    
    @IBAction func browseFile(sender: AnyObject) {
        // browse file callback
    }
}
