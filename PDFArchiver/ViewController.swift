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
    @IBOutlet var documentAC: NSArrayController!
    
    @IBOutlet weak var datePicker: NSDatePicker!
    @IBOutlet weak var descriptionField: NSTextField!
    @IBOutlet weak var tagField: NSTextField!
    @IBOutlet weak var filenameField: NSTextField!
    
    // outlets
    @IBAction func browseFile(sender: AnyObject) {
        browse_files()
    }
    @IBAction func saveButtonClicked(_ sender: Any) {
        // getting & setting the date/time value
        let myDate = datePicker.dateValue
        print(myDate)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func update_PDFView(url: URL) {
        pdfview.document = PDFDocument(url: url)
//        pdfview.displayMode = PDFDisplayMode.singlePageContinuous
        pdfview.displayMode = PDFDisplayMode.singlePage
        pdfview.autoScales = true
        pdfview.acceptsDraggedFiles = false
        pdfview.interpolationQuality = PDFInterpolationQuality.low
    }
}

extension ViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        
        if let identifier = tableView.identifier, identifier.rawValue == "DocumentTableView" {
            // update the PDFView
            let pdf_url = (self.documentAC.selectedObjects.first as! Document).path
            self.update_PDFView(url: pdf_url)
        }
    }
}
