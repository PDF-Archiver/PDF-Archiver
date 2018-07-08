//
//  ViewController.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Quartz
import os.log

protocol ViewControllerDelegate: class {
    func setDocuments(documents: [Document])
    func closeApp()
    func updateView(updatePDF: Bool)
}

class ViewController: NSViewController {
    internal let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "MainViewController")
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
        guard !self.documentAC.selectedObjects.isEmpty,
            let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
                return
        }

        // set the date of the pdf document
        selectedDocument.documentDate = sender.dateValue
    }

    @IBAction func descriptionDone(_ sender: NSTextField) {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty,
              let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
            return
        }

        // set the description of the pdf document
        self.dataModelInstance.setDocumentDescription(document: selectedDocument, description: sender.stringValue)
    }

    @IBAction func clickedDocumentTagTableView(_ sender: NSTableView) {
        // test if the document tag table is empty
        guard !self.documentAC.selectedObjects.isEmpty,
            let selectedDocument = self.documentAC.selectedObjects.first as? Document,
            let selectedTag = self.documentTagAC.selectedObjects.first as? Tag else {
                return
        }

        // remove the selected element
        self.dataModelInstance.remove(tag: selectedTag, from: selectedDocument)
    }

    @IBAction func clickedTagTableView(_ sender: NSTableView) {
        // add new tag to document table view
        guard let selectedDocument = self.documentAC.selectedObjects.first as? Document,
            let selectedTag = self.tagAC.selectedObjects.first as? Tag else {
                os_log("Please pick documents first!", log: self.log, type: .info)
                return
        }

        // test if element already exists in document tag table view
        let result = self.dataModelInstance.add(tag: selectedTag, to: selectedDocument)

        // if successful, clear search field content
        if result {
            self.tagSearchField.stringValue = ""
        }
    }

    @IBAction func browseFile(sender: AnyObject) {
//        let openPanel = getOpenPanel("Choose an observed folder")
//        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
//            guard response == NSApplication.ModalResponse.OK else { return }
//            self.dataModelInstance.prefs.observedPath = openPanel.url!
//            self.dataModelInstance.addUntaggedDocuments(paths: openPanel.urls)
//        }

        // TODO: debug code
        guard !self.documentAC.selectedObjects.isEmpty,
            let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
                return
        }
        print(selectedDocument.documentTags)
    }

    @IBAction func saveDocumentButton(_ sender: NSButton) {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty,
            let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
                return
        }

        guard let _ = self.dataModelInstance.prefs.archivePath else {
            dialogOK(messageKey: "no_archive", infoKey: "select_preferences", style: .critical)
            return
        }

        let result = self.dataModelInstance.saveDocumentInArchive(document: selectedDocument)

        if result {
            // update the array controller
            self.documentAC.content = self.dataModelInstance.untaggedDocuments

            // select a new document, which is not already done
            var newIndex = 0
            var documents = (self.documentAC.arrangedObjects as? [Document]) ?? []
            for idx in 0...documents.count-1 where documents[idx].documentDone == "" {
                newIndex = idx
                break
            }
            self.documentAC.setSelectionIndex(newIndex)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // MARK: - delegates
        self.tagSearchField.delegate = self
        self.descriptionField.delegate = self
        self.dataModelInstance.viewControllerDelegate = self

        // set the array controller
        self.tagAC.content = self.dataModelInstance.tags
        self.documentAC.content = self.dataModelInstance.untaggedDocuments

        // add sorting to tag fields
        self.documentAC.sortDescriptors = [NSSortDescriptor(key: "documentDone", ascending: false),
                                           NSSortDescriptor(key: "name", ascending: true)]
        self.tagTableView.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false),
                                             NSSortDescriptor(key: "name", ascending: true)]

        // set the date picker to canadian local, e.g. YYYY-MM-DD
        self.datePicker.locale = Locale.init(identifier: "en_CA")

        // set some PDF View settings
        self.pdfContentView.displayMode = PDFDisplayMode.singlePage
        self.pdfContentView.autoScales = true
        self.pdfContentView.acceptsDraggedFiles = false
        self.pdfContentView.interpolationQuality = PDFInterpolationQuality.low

        // update the view after all the settigns
        self.documentAC.setSelectionIndex(0)
    }

    override func viewWillAppear() {
        // set background color of the view
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor(named: NSColor.Name("OffWhite"))!.cgColor
        let cornerRadius = CGFloat(3)

        self.pdfDocumentsView.wantsLayer = true
        self.pdfDocumentsView.layer?.backgroundColor = NSColor(named: NSColor.Name("DarkGreyBlue"))!.withAlphaComponent(0.1).cgColor
        self.pdfDocumentsView.layer?.cornerRadius = cornerRadius

        self.pdfView.wantsLayer = true
        self.pdfView.layer?.backgroundColor = NSColor(named: NSColor.Name("DarkGreyBlue"))!.withAlphaComponent(0.1).cgColor
        self.pdfView.layer?.cornerRadius = cornerRadius

        self.pdfContentView.backgroundColor = NSColor(named: NSColor.Name("DarkGrey"))!
        self.pdfContentView.layer?.cornerRadius = cornerRadius

        self.documentAttributesView.wantsLayer = true
        self.documentAttributesView.layer?.backgroundColor = NSColor(named: NSColor.Name("DarkGreyBlue"))!.withAlphaComponent(0.1).cgColor
        self.documentAttributesView.layer?.cornerRadius = cornerRadius

        self.tagSearchView.wantsLayer = true
        self.tagSearchView.layer?.backgroundColor = NSColor(named: NSColor.Name("DarkGreyBlue"))!.withAlphaComponent(0.1).cgColor
        self.tagSearchView.layer?.cornerRadius = cornerRadius
    }

    override func viewDidAppear() {
        // test if the app needs subscription validation
        var isValid: Bool
        #if RELEASE
            os_log("RELEASE", log: self.log, type: .debug)
            isValid = self.dataModelInstance.store.appUsagePermitted()
        #else
            os_log("NO RELEASE", log: self.log, type: .debug)
            isValid = true
        #endif

        // show onboarding view
        if !UserDefaults.standard.bool(forKey: "onboardingShown") || isValid == false {
            self.showOnboardingMenuItem(self)
        }
    }

    override func viewDidDisappear() {
        if let archivePath = self.dataModelInstance.prefs.archivePath {
            // reset the tag count to the archived documents
            for document in (self.documentAC.arrangedObjects as? [Document]) ?? [] where document.documentDone == "" {
                for tag in document.documentTags ?? [] {
                    tag.count -= 1
                }
            }

            // save the tag count
            self.dataModelInstance.prefs.save()
            os_log("Save complete: %@", log: self.log, type: .debug, archivePath.absoluteString)

        } else {
            os_log("Save possible.", log: self.log, type: .debug)
        }

        // quit application if the window disappears
        NSApplication.shared.terminate(self)
    }

}
