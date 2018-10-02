//
//  ViewController.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import os.log
import Quartz

protocol ViewControllerDelegate: class {
    func setDocuments(documents: [Document])
    func clearTagSearchField()
    func closeApp()
    func updateView(updatePDF: Bool)
}

class ViewController: NSViewController, Logging {
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
    @IBOutlet weak var specificationField: NSTextField!
    @IBOutlet weak var tagSearchField: NSSearchField!

    // outlets
    @IBAction func datePickDone(_ sender: NSDatePicker) {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty,
            let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
                return
        }

        // set the date of the pdf document
        selectedDocument.date = sender.dateValue
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
        self.dataModelInstance.add(tag: selectedTag, to: selectedDocument)
    }

    @IBAction func browseFile(sender: AnyObject) {
        let openPanel = getOpenPanel("Choose an observed folder")
        guard let mainWindow = NSApplication.shared.mainWindow else { fatalError("Main Window not found!") }
        guard let openPanelUrl = openPanel.url else { fatalError("Open panel URL not found!") }
        openPanel.beginSheetModal(for: mainWindow) { response in
            guard response == NSApplication.ModalResponse.OK else { return }
            self.dataModelInstance.prefs.observedPath = openPanelUrl
            self.dataModelInstance.addUntaggedDocuments(paths: openPanel.urls)
        }
    }

    @IBAction func saveDocumentButton(_ sender: NSButton) {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty,
            let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
                return
        }

        guard self.dataModelInstance.prefs.archivePath != nil else {
            dialogOK(messageKey: "no_archive", infoKey: "select_preferences", style: .critical)
            return
        }

        let result = self.dataModelInstance.saveDocumentInArchive(document: selectedDocument)

        if result {
            // select a new document, which is not already done
            var newIndex = 0
            var documents = (self.documentAC.arrangedObjects as? [Document]) ?? []
            for idx in 0...documents.count - 1 where documents[idx].documentDone.isEmpty {
                newIndex = idx
                break
            }
            self.documentAC.setSelectionIndex(newIndex)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // set delegates
        self.tagSearchField.delegate = self
        self.specificationField.delegate = self
        self.dataModelInstance.viewControllerDelegate = self

        // add sorting
        self.documentAC.sortDescriptors = [NSSortDescriptor(key: "documentDone", ascending: false),
                                           NSSortDescriptor(key: "name", ascending: true)]
        self.tagTableView.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false),
                                             NSSortDescriptor(key: "name", ascending: true)]

        // set the date picker to canadian local, e.g. YYYY-MM-DD
        self.datePicker.locale = Locale(identifier: "en_CA")

        // set some PDF View settings
        self.pdfContentView.displayMode = PDFDisplayMode.singlePage
        self.pdfContentView.autoScales = true
        self.pdfContentView.acceptsDraggedFiles = false
        self.pdfContentView.interpolationQuality = PDFInterpolationQuality.low

        // update the view after all the settigns
        self.documentAC.setSelectionIndex(0)
    }

    override func viewWillAppear() {
        // set the array controller
        self.tagAC.content = self.dataModelInstance.tags
        self.documentAC.content = self.dataModelInstance.untaggedDocuments
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
            for document in (self.documentAC.arrangedObjects as? [Document]) ?? [] where document.documentDone.isEmpty {
                for tag in document.documentTags {
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
