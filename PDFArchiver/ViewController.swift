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
    
    var defaultTags = [Tag]()
    var prefs: Preferences?
    var dataModelInstance: DataModel?
    
    @IBOutlet weak var pdfview: PDFView!
    @IBOutlet weak var tagTableView: NSTableView!
    
    @IBOutlet var documentAC: NSArrayController!
    @IBOutlet var tagAC: NSArrayController!
    @IBOutlet var documentTagAC: NSArrayController!
    
    @IBOutlet weak var datePicker: NSDatePicker!
    @IBOutlet weak var descriptionField: NSTextField!
    @IBOutlet weak var tagSearchField: NSSearchField!
    
    // outlets
    @IBAction func clickedTableView(_ sender: NSTableView) {
//        if sender.clickedRow == -1 {
//            if sender.clickedColumn == 0 {
//                sortArrayController(by: "count", ascending: false)
//                sort(objs: [Tag], by key: String, ascending: Bool)
//            } else {
//                sortArrayController(by: "name", ascending: true)
//            }
//        } else {
//            tagTableView.deselectRow(tagAC.selectionIndex)
//        }
    }
    @IBAction func clickedDocumentTagTableView(_ sender: NSTableView) {
        documentTagAC.remove(atArrangedObjectIndex: sender.clickedRow)
    }
    
    @IBAction func browseFile(sender: AnyObject) {
        getPDFDocuments()
    }
    @IBAction func tagSearchField(_ sender: Any) {
        // get the right tag
        let tag_name: String
        let selectedTag = (tagAC.content as! [Tag]).first
        if selectedTag != nil {
            tag_name = selectedTag!.name
        } else {
            tag_name = tagSearchField.stringValue
        }

        // test if element already exists in document tag table view
        for element in documentTagAC.arrangedObjects as! [Tag] {
            if tag_name == element.name {
                return
            }
        }
        
        // add new tag to document table view
        let tag = Tag(name: tag_name, count: 0)
        documentTagAC.addObject(tag)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create data model instance
        self.dataModelInstance = DataModel()
//        self.dataModelInstance?.delegate = self as DocumentDelegate
        
        self.tagAC.content = self.dataModelInstance?.tags?.list
        self.documentAC.content = self.dataModelInstance?.documents
        
        //MARK: Notification Observer
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(self.showPreferences), name: Notification.Name("ShowPreferences"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.getPDFDocuments), name: Notification.Name("GetPDFDocuments"), object: nil)
        
        //MARK: delegates
        tagSearchField.delegate = self
        
        // add sorting to tag fields
//        documentAC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
    }
    
}
