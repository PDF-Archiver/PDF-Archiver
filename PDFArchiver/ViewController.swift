//
//  ViewController.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Quartz

class ViewController: NSViewController {
    var dataModelInstance = DataModel()
    
    @IBOutlet weak var pdfview: PDFView!
    @IBOutlet weak var tagTableView: NSTableView!
    
    @IBOutlet var documentAC: NSArrayController!
    @IBOutlet var tagAC: NSArrayController!
    @IBOutlet var documentTagAC: NSArrayController!
    
    @IBOutlet weak var datePicker: NSDatePicker!
    @IBOutlet weak var descriptionField: NSTextField!
    @IBOutlet weak var tagSearchField: NSSearchField!
    
    // outlets
    @IBAction func datePickDone(_ sender: NSDatePicker) {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty else {
            return
        }
        
        // set the date of the pdf document
        let document = self.dataModelInstance.documents![self.dataModelInstance.document_idx!] as Document
        document.pdf_date = sender.dateValue
    }
    
    @IBAction func descriptionDone(_ sender: NSTextField) {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty else {
            return
        }
        
        // set the description of the pdf document
        let document = self.dataModelInstance.documents![self.dataModelInstance.document_idx!] as Document
        document.pdf_description = sender.stringValue
    }
    
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
    
    @IBAction func clickedDocumentTagTableView(_ sender: NSTableView) {
        // test if the document tag table is empty
        guard !self.documentTagAC.selectedObjects.isEmpty else {
            return
        }
        
        // remove the selected element
        let idx = self.dataModelInstance.document_idx
        var i = 0
        for tag in self.dataModelInstance.documents![idx!].pdf_tags! {
            if tag.name == (self.documentTagAC.selectedObjects.first as! Tag).name {
                self.dataModelInstance.documents![idx!].pdf_tags!.remove(at: i)
                self.updateViewController(update_pdf: false)
                return
            }
            i += 1
        }
    }
    
    @IBAction func browseFile(sender: AnyObject) {
        self.getPDFDocuments()
    }
    @IBAction func saveDocumentButton(_ sender: NSButton) {
        self.saveDocument()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tagAC.content = self.dataModelInstance.tags?.list
        self.documentAC.content = self.dataModelInstance.documents
        
        // MARK: - Notification Observer
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(self.showPreferences), name: Notification.Name("ShowPreferences"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.getPDFDocuments), name: Notification.Name("GetPDFDocuments"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.saveDocument), name: Notification.Name("SaveDocument"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.updateViewController), name: Notification.Name("UpdateViewController"), object: nil)
        
        // MARK: - delegates
        tagSearchField.delegate = self
        descriptionField.delegate = self
        
        // add sorting to tag fields
        sortArrayController(by: "count", ascending: false)
//        documentAC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
    }
    
}
