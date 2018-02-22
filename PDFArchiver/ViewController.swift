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

    @IBOutlet weak var pdfDocumentsView: NSView!
    @IBOutlet weak var pdfView: NSView!
    @IBOutlet weak var pdfContentView: PDFView!
    @IBOutlet weak var documentAttributesView: NSView!
    @IBOutlet weak var tagSearchView: NSView!
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
        guard let obj = self.documentTagAC.selectedObjects.first as? Tag else { return }
        for tag in self.dataModelInstance.documents![idx!].documentTags! {
            if tag.name == obj.name {
                self.dataModelInstance.documents![idx!].documentTags!.remove(at: i)
                tag.count -= 1

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

        // set the date picker to canadian local, e.g. YYYY-MM-DD
        self.datePicker.locale = Locale.init(identifier: "en_CA")

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
        notificationCenter.addObserver(self, selector: #selector(self.resetCache),
                                       name: Notification.Name("ResetCache"), object: nil)

        // MARK: - delegates
        tagSearchField.delegate = self
        descriptionField.delegate = self

        // add sorting to tag fields
        sortArrayController(by: "count", ascending: false)

        // set some PDF View settings
//         self.pdfContentView.displayMode = PDFDisplayMode.singlePageContinuous
        self.pdfContentView.displayMode = PDFDisplayMode.singlePage
        self.pdfContentView.autoScales = true
        if #available(OSX 10.13, *) {
            self.pdfContentView.acceptsDraggedFiles = false
        }
        self.pdfContentView.interpolationQuality = PDFInterpolationQuality.low
    }

    override func viewWillAppear() {
        let layout = Layout()

        // set background color of the view
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = layout.color3

        self.pdfDocumentsView.wantsLayer = true
        self.pdfDocumentsView.layer?.backgroundColor = layout.fieldBackgroundColorLight
        self.pdfDocumentsView.layer?.cornerRadius = layout.cornerRadius

        self.pdfView.wantsLayer = true
        self.pdfView.layer?.backgroundColor = layout.fieldBackgroundColorLight
        self.pdfView.layer?.cornerRadius = layout.cornerRadius

        self.pdfContentView.backgroundColor = NSColor.init(cgColor: layout.color5)!
        self.pdfContentView.layer?.cornerRadius = layout.cornerRadius

        self.documentAttributesView.wantsLayer = true
        self.documentAttributesView.layer?.backgroundColor = layout.fieldBackgroundColorLight
        self.documentAttributesView.layer?.cornerRadius = layout.cornerRadius

        self.tagSearchView.wantsLayer = true
        self.tagSearchView.layer?.backgroundColor = layout.fieldBackgroundColorLight
        self.tagSearchView.layer?.cornerRadius = layout.cornerRadius
    }

    override func viewDidDisappear() {
        if let prefs = self.dataModelInstance.prefs,
           let archivePath = self.dataModelInstance.prefs?.archivePath {
            prefs.save()
            print("\nSAVE COMPLETE\n")
        } else {
            print("\nSAVE NOT POSSIBLE\n")
        }
    }
}
