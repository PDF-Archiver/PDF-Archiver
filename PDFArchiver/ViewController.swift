//
//  ViewController.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Quartz

class ViewController: NSViewController {
    //https://color.adobe.com/de/Simple-Theme-color-theme-10451401/
    let color1 = CGColor.init(red: 0.793, green: 0.255, blue: 0.310, alpha: 1)
    let color2 = CGColor.init(red: 0.903, green: 0.412, blue: 0.404, alpha: 1)
    let color3 = CGColor.init(red: 0.980, green: 0.980, blue: 0.980, alpha: 1)
    let color4 = CGColor.init(red: 0.131, green: 0.172, blue: 0.231, alpha: 1)
    let color5 = CGColor.init(red: 0.213, green: 0.242, blue: 0.286, alpha: 1)

    var dataModelInstance = DataModel()

    @IBOutlet weak var pdfview: PDFView!
    @IBOutlet weak var documentCustomView: NSView!
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
        let document = self.dataModelInstance.documents![self.dataModelInstance.documentIdx!] as Document
        document.documentDate = sender.dateValue
    }

    @IBAction func descriptionDone(_ sender: NSTextField) {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty else {
            return
        }

        // set the description of the pdf document
        let document = self.dataModelInstance.documents![self.dataModelInstance.documentIdx!] as Document
        document.documentDescription = sender.stringValue
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
        let idx = self.dataModelInstance.documentIdx
        var i = 0
        for tag in self.dataModelInstance.documents![idx!].documentTags! {
            guard let obj = self.documentTagAC.selectedObjects.first as? Tag else { return }
            if tag.name == obj.name {
                self.dataModelInstance.documents![idx!].documentTags!.remove(at: i)
                self.updateViewController(updatePDF: false)
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

        // set the array controller
        self.tagAC.content = self.dataModelInstance.tags?.list
        self.documentAC.content = self.dataModelInstance.documents

        // MARK: - Notification Observer
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(self.showPreferences),
                                       name: Notification.Name("ShowPreferences"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.getPDFDocuments),
                                       name: Notification.Name("GetPDFDocuments"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.saveDocument),
                                       name: Notification.Name("SaveDocument"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.updateViewController),
                                       name: Notification.Name("UpdateViewController"), object: nil)

        // MARK: - delegates
        tagSearchField.delegate = self
        descriptionField.delegate = self

        // add sorting to tag fields
        sortArrayController(by: "count", ascending: false)
//        documentAC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

    }

    override func viewWillAppear() {
        // set background color of the view
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = CGColor.init(red: 141/255, green: 189/255, blue: 246/255, alpha: 0.9)
        self.documentCustomView.wantsLayer = true
        self.documentCustomView.layer?.backgroundColor = CGColor.init(red: 1, green: 1, blue: 1, alpha: 0.9)
        self.documentCustomView.layer?.cornerRadius = 15

    }
}
