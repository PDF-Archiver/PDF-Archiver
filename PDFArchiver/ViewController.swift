//
//  ViewController.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Quartz
import os.log

protocol ViewControllerDelegate: class {
    func setDocuments(documents: [Document])
}

class ViewController: NSViewController, ViewControllerDelegate {
    let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "MainViewController")
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
            let selectedDocument = self.dataModelInstance.selectedDocument else {
                return
        }

        // set the date of the pdf document
        selectedDocument.documentDate = sender.dateValue
    }

    @IBAction func descriptionDone(_ sender: NSTextField) {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty,
              let selectedDocument = self.dataModelInstance.selectedDocument else {
            return
        }

        // set the description of the pdf document
        selectedDocument.documentDescription = sender.stringValue
    }

    @IBAction func clickedDocumentTagTableView(_ sender: NSTableView) {
        // test if the document tag table is empty
        guard !self.documentAC.selectedObjects.isEmpty,
            let selectedDocument = self.dataModelInstance.selectedDocument,
            let obj = self.documentTagAC.selectedObjects.first as? Tag else {
                return
        }

        // remove the selected element
        var documentTags = selectedDocument.documentTags ?? []
        for (index, tag) in documentTags.enumerated() where tag.name == obj.name {
            documentTags.remove(at: index)
            tag.count -= 1

            selectedDocument.documentTags = documentTags
            self.updateViewController(updatePDF: false)
            break
        }
    }

    @IBAction func clickedTagTableView(_ sender: NSTableView) {
        if let selectedTag = self.tagAC.selectedObjects.first as? Tag {
            self.addDocumentTag(tag: selectedTag,
                                new: false)
        }
    }

    @IBAction func browseFile(sender: AnyObject) {
        self.getPDFDocuments()
    }

    @IBAction func saveDocumentButton(_ sender: NSButton) {
        self.saveDocument()
    }

    func setDocuments(documents: [Document]) {
        self.documentAC.content = documents
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // set the data model VC delegate
        self.dataModelInstance.viewControllerDelegate = self

        // get the security scope bookmark [https://stackoverflow.com/a/35863729]
        var archivePath: NSURL? = nil
        if let bookmarkData = UserDefaults.standard.object(forKey: "securityScopeBookmark") as? Data {
            do {
                archivePath = try NSURL.init(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: nil)
                if let archivePathTmp = archivePath {
                    archivePathTmp.startAccessingSecurityScopedResource()
                }
            } catch let error as NSError {
                os_log("Bookmark Access failed: %@", log: self.log, type: .error, error.description as CVarArg)
            }
        }

        // get the security scope bookmark of the observed path
        if let bookmarkData = UserDefaults.standard.object(forKey: "securityScopeBookmarkObservedPath") as? Data {
            do {
                let observedPath = try NSURL.init(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: nil)
                observedPath.startAccessingSecurityScopedResource()
            } catch let error as NSError {
                os_log("Bookmark Access failed: %@", log: self.log, type: .error, error.description as CVarArg)
            }
        }

        // set the date picker to canadian local, e.g. YYYY-MM-DD
        self.datePicker.locale = Locale.init(identifier: "en_CA")

        // get the new documents
        if let observedPath = self.dataModelInstance.prefs?.observedPath {
            self.dataModelInstance.addDocuments(paths: [observedPath])
        }

        // set the array controller
        self.tagAC.content = self.dataModelInstance.tags
        self.documentAC.content = self.dataModelInstance.documents

        // MARK: - Notification Observer
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(self.showPreferences),
                                       name: Notification.Name("ShowPreferences"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.updateViewController),
                                       name: Notification.Name("UpdateViewController"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.resetCache),
                                       name: Notification.Name("ResetCache"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.showOnboarding),
                                       name: Notification.Name("ShowOnboarding"), object: nil)
        notificationCenter.addObserver(self, selector: #selector(self.updateTags),
                                       name: Notification.Name("UpdateTags"), object: nil)

        // MARK: - delegates
        tagSearchField.delegate = self
        descriptionField.delegate = self

        // add sorting to tag fields
        self.documentAC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true),
                                           NSSortDescriptor(key: "documentDone", ascending: false)]
        self.tagTableView.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false),
                                             NSSortDescriptor(key: "name", ascending: true)]

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

    override func viewDidAppear() {
        // show onboarding view
        if !UserDefaults.standard.bool(forKey: "onboardingShown") {
            self.showOnboarding()
        }
    }

    override func viewDidDisappear() {
        if let prefs = self.dataModelInstance.prefs,
           let archivePath = self.dataModelInstance.prefs?.archivePath {
            prefs.save()
            os_log("Save complete: %@", log: self.log, type: .debug, archivePath as CVarArg)
        } else {
            os_log("Save possible.", log: self.log, type: .debug)
        }

        // quit application if the window disappears
        NSApplication.shared.terminate(self)
    }

}
