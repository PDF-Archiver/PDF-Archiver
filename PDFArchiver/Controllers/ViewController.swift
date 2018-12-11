//
//  ViewController.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import OrderedSet
import os.log
import Quartz

protocol ViewControllerDelegate: class {
    func clearTagSearchField()
    func closeApp()
    func updateView(updatePDF: Bool)
}

class ViewController: NSViewController, Logging {
    var dataModelInstance = DataModel()

    @IBOutlet weak var documentTableView: NSTableView!
    @IBOutlet weak var documentTagsTableView: NSTableView!
    @IBOutlet weak var tagTableView: NSTableView!

    @IBOutlet weak var pdfView: NSView!
    @IBOutlet weak var pdfContentView: PDFView!
    @IBOutlet weak var documentAttributesView: NSView!
    @IBOutlet weak var tagSearchView: NSView!

    @IBOutlet var documentTagAC: NSArrayController!

    @IBOutlet weak var datePicker: NSDatePicker!
    @IBOutlet weak var specificationField: NSTextField!
    @IBOutlet weak var tagSearchField: NSSearchField!

    // TODO: choose another place for this
    func getSelectedDocument() -> Document? {
        let index = self.documentTableView.selectedRow
        if index >= 0 && index < self.dataModelInstance.untaggedDocuments.count {
            return self.dataModelInstance.untaggedDocuments[index]
        } else {
            return nil
        }
    }
    private func getSelectedTag() -> Tag? {
        let index = tagTableView.selectedRow
        return dataModelInstance.tagManager.getPresentedTags()[index]
    }

    // outlets
    @IBAction private func datePickDone(_ sender: NSDatePicker) {

        // test if a document is selected
        guard let selectedDocument = getSelectedDocument() else {
                return
        }

        // set the date of the pdf document
        selectedDocument.date = sender.dateValue
    }

    @IBAction private func descriptionDone(_ sender: NSTextField) {
        // test if a document is selected
        guard let selectedDocument = getSelectedDocument() else {
            return
        }

        // set the description of the pdf document
        self.dataModelInstance.setDocumentDescription(document: selectedDocument, description: sender.stringValue)
    }

    @IBAction private func clickedDocumentTagTableView(_ sender: NSTableView) {
        // test if the document tag table is empty
        guard let selectedDocument = getSelectedDocument(),
            let selectedTag = self.documentTagAC.selectedObjects.first as? Tag else {
                return
        }

        // remove the selected element
        self.dataModelInstance.remove(tag: selectedTag, from: selectedDocument)
    }

    @IBAction private func clickedTagTableView(_ sender: NSTableView) {
        // add new tag to document table view
        guard let selectedDocument = getSelectedDocument(),
            let selectedTag = getSelectedTag() else {
                os_log("Please pick documents first!", log: self.log, type: .info)
                return
        }

        // test if element already exists in document tag table view
        self.dataModelInstance.add(tag: selectedTag, to: selectedDocument)
    }

    @IBAction private func browseFile(sender: AnyObject) {
        let openPanel = getOpenPanel("Choose an observed folder")
        guard let mainWindow = NSApplication.shared.mainWindow else { fatalError("Main Window not found!") }
        openPanel.beginSheetModal(for: mainWindow) { response in

            guard response == NSApplication.ModalResponse.OK,
                let openPanelUrl = openPanel.url else { return }

            self.dataModelInstance.prefs.observedPath = openPanelUrl
            self.dataModelInstance.addUntaggedDocuments(paths: openPanel.urls)
        }
    }

    @IBAction private func saveDocumentButton(_ sender: NSButton) {
        // test if a document is selected
        guard let selectedDocument = getSelectedDocument() else {
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
            var documents = self.dataModelInstance.untaggedDocuments
            for idx in 0...documents.count - 1 where documents[idx].path.hasParent(self.dataModelInstance.prefs.archivePath) {
                newIndex = idx
                break
            }
//            self.documentAC.setSelectionIndex(newIndex)
            self.documentTableView.selectRowIndexes(IndexSet([newIndex]), byExtendingSelection: false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // set delegates
        self.documentTableView.dataSource = self
        self.documentTableView.delegate = self
        self.documentTableView.target = self
//        self.documentTagsTableView.dataSource = self
//        self.documentTagsTableView.delegate = self
//        self.documentTagsTableView.target = self
        self.tagTableView.dataSource = self
        self.tagTableView.delegate = self
        self.tagTableView.target = self

        self.tagSearchField.delegate = self
        self.specificationField.delegate = self
        self.dataModelInstance.viewControllerDelegate = self

        // add sorting
        self.documentTableView.sortDescriptors = [NSSortDescriptor(key: "documentDone", ascending: false),
                                                   NSSortDescriptor(key: "name", ascending: true)]
        self.tagTableView.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false),
                                             NSSortDescriptor(key: "name", ascending: true)]

        // set the date picker to canadian local, e.g. YYYY-MM-DD
        self.datePicker.locale = Locale(identifier: "en_CA")

        // set some PDF View settings
        self.pdfContentView.displayMode = PDFDisplayMode.singlePage
        self.pdfContentView.autoScales = true
        if #available(OSX 10.13, *) {
            self.pdfContentView.acceptsDraggedFiles = false
        }
        self.pdfContentView.interpolationQuality = PDFInterpolationQuality.low

        // update the view after all the settigns
//        self.documentAC.setSelectionIndex(0)
        self.documentTableView.selectRowIndexes(IndexSet([0]), byExtendingSelection: false)

        self.documentTableView.reloadData()
        self.documentTagsTableView.reloadData()
        self.tagTableView.reloadData()
    }

//    override func viewWillAppear() {
//        // set the array controller
//        self.tagAC.content = self.dataModelInstance.tags
////        self.documentAC.content = self.dataModelInstance.untaggedDocuments
//        self.documentTableView.reloadData()
//    }

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
            self.performSegue(withIdentifier: "onboardingSegue", sender: self)
        }
    }

    override func viewDidDisappear() {
        if let archivePath = self.dataModelInstance.prefs.archivePath {
            // reset the tag count to the archived documents
            for document in self.dataModelInstance.untaggedDocuments where document.path.hasParent(self.dataModelInstance.prefs.archivePath) {
                for tag in document.tags {
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
