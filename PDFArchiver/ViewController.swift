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
    @IBOutlet weak var tagTableView: NSTableView!
    @IBOutlet var documentAC: NSArrayController!
    @IBOutlet var tagAC: NSArrayController!
    @IBOutlet var searchTagAC: NSArrayController!
    @IBOutlet var documentTagAC: NSArrayController!
    
    @IBOutlet weak var datePicker: NSDatePicker!
    @IBOutlet weak var descriptionField: NSTextField!
    @IBOutlet weak var filenameField: NSTextField!
    @IBOutlet weak var searchTagTableView: NSTableView!
    
    // outlets
    @IBAction func clickedTableView(_ sender: NSTableView) {
        if sender.clickedRow == -1 {
            if sender.clickedColumn == 0 {
                sortArrayController(by: "count", ascending: false)
            } else {
                sortArrayController(by: "name", ascending: true)
            }
        } else {
            tagTableView.deselectRow(tagAC.selectionIndex)
        }
    }
    
    @IBAction func browseFile(sender: AnyObject) {
        browse_files()
    }
    @IBAction func saveButtonClicked(_ sender: Any) {
        // getting & setting the date/time value
        let myDate = datePicker.dateValue
        print(myDate)
    }

    var tagSearchTable = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: debug code to reset the preferences
//        UserDefaults.standard.removeObject(forKey: "archivePath")
//        UserDefaults.standard.removeObject(forKey: "tags")
        
        self.refresh_tags()
        
        // TODO: example usage of the update search field tags function
        self.update_search_field_tags(search: "a")
        
    }
    
    func refresh_tags() {
        let tags_dict = UserDefaults.standard.dictionary(forKey: "tags")!
        
        var tags = [Tag]()
        for (name, count) in tags_dict {
            tags.append(Tag(name: name, count: count as! Int))
        }
        sortArrayController(by: "count", ascending: false)
        tagAC.content = tags
        tagTableView.deselectRow(tagAC.selectionIndex)
    }
    
    func update_search_field_tags(search: String) {
        var tags = [Tag]()
        for tag in tagAC.arrangedObjects as! [Tag] {
            if tag.name.hasPrefix(search) {
                let obj = Tag(name: tag.name, count: 0)
                tags.append(obj)
            }
        }
        searchTagAC.content = tags
    }
    
    func sortArrayController(by key : String, ascending asc : Bool) {
        tagAC.sortDescriptors = [NSSortDescriptor(key: key, ascending: asc)]
        tagAC.rearrangeObjects()
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

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        
        if let identifier = tableView.identifier, identifier.rawValue == "DocumentTableView" {
            // update the PDFView
            let pdf_url = (self.documentAC.selectedObjects.first as! Document).path
            self.update_PDFView(url: pdf_url)
        }
    }

}
