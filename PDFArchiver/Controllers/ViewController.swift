//
//  ViewController.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import Quartz

typealias TableViewChanges = (deleted: IndexSet, inserted: IndexSet)
class ViewController: NSViewController, Logging {

    var dataModelInstance = DataModel()

    @IBOutlet weak var documentTableView: NSTableView!
    @IBOutlet weak var documentTagsTableView: NSTableView!
    @IBOutlet weak var tagTableView: NSTableView!

    @IBOutlet weak var pdfView: NSView!
    @IBOutlet weak var pdfContentView: PDFView!
    @IBOutlet weak var documentAttributesView: NSView!
    @IBOutlet weak var tagSearchView: NSView!

    @IBOutlet weak var datePicker: NSDatePicker!
    @IBOutlet weak var specificationField: NSTextField!
    @IBOutlet weak var tagSearchField: NSSearchField!

    // outlets
    @IBAction private func datePickDone(_ sender: NSDatePicker) {

        // test if a document is selected
        guard let selectedDocument = dataModelInstance.selectedDocument else {
                return
        }

        // set the date of the pdf document
        selectedDocument.date = sender.dateValue

        // update the document attributes
        updateView(.documentAttributes)
    }

    @IBAction private func descriptionDone(_ sender: NSTextField) {
        // test if a document is selected
        guard let selectedDocument = dataModelInstance.selectedDocument else {
            return
        }

        // set the description of the pdf document
        dataModelInstance.setDocumentDescription(document: selectedDocument, description: sender.stringValue)

        // update the document attributes in case the input string should be slugified
        updateView(.documentAttributes)
    }

    @IBAction private func clickedDocumentTagTableView(_ sender: NSTableView) {

        // remove the selected tag
        removeSelectedTagFromSelectedDocument()
    }

    @IBAction private func clickedTagTableView(_ sender: NSTableView) {

        // validate the table view index
        guard dataModelInstance.sortedTags.indices.contains(tagTableView.selectedRow) else { return }
        let selectedTag = dataModelInstance.sortedTags[tagTableView.selectedRow]

        // test if element already exists in document tag table view
        dataModelInstance.addTagToSelectedDocument(selectedTag.name)

        // update the view
        updateView(.documentAttributes)
    }

    @IBAction private func browseFile(sender: AnyObject) {
        let openPanel = getOpenPanel("Choose an observed folder")
        guard let mainWindow = NSApplication.shared.mainWindow else { fatalError("Main Window not found!") }
        openPanel.beginSheetModal(for: mainWindow) { response in

            guard response == NSApplication.ModalResponse.OK,
                let openPanelUrl = openPanel.url else { return }

            self.dataModelInstance.prefs.observedPath = openPanelUrl

            // update the untagged documents
            self.dataModelInstance.updateUntaggedDocuments(paths: openPanel.urls)

            // reload the documents in the table view
            self.updateView(.documents)
        }
    }

    @IBAction private func saveDocumentButton(_ sender: NSButton) {

        guard dataModelInstance.prefs.archivePath != nil else {
            dialogOK(messageKey: "no_archive", infoKey: "select_preferences", style: .critical)
            return
        }

        do {
            // try to move the selected document
            try dataModelInstance.saveDocumentInArchive()

            // set the sort descriptors again, to force the new sorting of the documents
            dataModelInstance.documentSortDescriptors = documentTableView.sortDescriptors

            // update only the documents and tags, since the rest will be updated by the selection change
            updateView([.documents, .tags])

            // select the first untagged document
            let newIndex = dataModelInstance.sortedDocuments.firstIndex { $0.taggingStatus == .untagged } ?? 0
            documentTableView.selectRowIndexes(IndexSet([newIndex]), byExtendingSelection: false)

            // increment count an request a review?
            AppStoreReviewRequest.shared.incrementCount()

        } catch DataModelError.noDocumentSelected {
            os_log("No document was selected.", log: log, type: .error)
        } catch let error {
            os_log("An error occured while renaming the document: ", log: log, type: .error, error.localizedDescription)
            dialogOK(messageKey: "save_failed", infoKey: "file_already_exists", style: .warning)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // set delegates
        documentTableView.dataSource = self
        documentTableView.delegate = self
        documentTableView.target = self
        documentTagsTableView.dataSource = self
        documentTagsTableView.delegate = self
        documentTagsTableView.target = self
        tagTableView.dataSource = self
        tagTableView.delegate = self
        tagTableView.target = self

        tagSearchField.delegate = self
        specificationField.delegate = self
        dataModelInstance.viewControllerDelegate = self

        // add sorting
        documentTableView.tableColumns[0].sortDescriptorPrototype = NSSortDescriptor(key: DataModel.DocumentOrder.taggingStatus.rawValue, ascending: true)
        documentTableView.tableColumns[1].sortDescriptorPrototype = NSSortDescriptor(key: DataModel.DocumentOrder.filename.rawValue, ascending: true)
        tagTableView.tableColumns[0].sortDescriptorPrototype = NSSortDescriptor(key: DataModel.TagOrder.count.rawValue, ascending: true)
        tagTableView.tableColumns[1].sortDescriptorPrototype = NSSortDescriptor(key: DataModel.TagOrder.name.rawValue, ascending: true)

        // add initial sort descriptors
        documentTableView.sortDescriptors = dataModelInstance.documentSortDescriptors
        tagTableView.sortDescriptors = dataModelInstance.tagSortDescriptors

        // set the date picker to canadian local, e.g. YYYY-MM-DD
        datePicker.locale = Locale(identifier: "en_CA")

        // set some PDF View settings
        pdfContentView.displayMode = PDFDisplayMode.singlePage
        pdfContentView.autoScales = true
        if #available(OSX 10.13, *) {
            pdfContentView.acceptsDraggedFiles = false
        }
        pdfContentView.interpolationQuality = PDFInterpolationQuality.low

        // update the view after all the settigns
        documentTableView.selectRowIndexes(IndexSet([0]), byExtendingSelection: false)

        documentTableView.reloadData()
        documentTagsTableView.reloadData()
        tagTableView.reloadData()
    }

    override func viewDidAppear() {
        // test if the app needs subscription validation
        var isValid: Bool
        #if RELEASE
            os_log("RELEASE", log: log, type: .debug)
            isValid = dataModelInstance.store.appUsagePermitted()
        #else
            os_log("NO RELEASE", log: log, type: .debug)
            isValid = true
        #endif

        // show onboarding view
        if !UserDefaults.standard.bool(forKey: "onboardingShown") || isValid == false {
            performSegue(withIdentifier: "onboardingSegue", sender: self)
        }
    }

    override func viewDidDisappear() {
        if let archivePath = dataModelInstance.prefs.archivePath {
            // save the tag count
            dataModelInstance.savePreferences()
            os_log("Save complete: %@", log: log, type: .debug, archivePath.absoluteString)

        } else {
            os_log("Save possible.", log: log, type: .debug)
        }

        // quit application if the window disappears
        NSApplication.shared.terminate(self)
    }

    // MARK: - segue stuff
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let tabViewController = segue.destinationController as? NSTabViewController {
            for controller in tabViewController.children {
                if let controller = controller as? MainPreferencesVC {
                    controller.preferencesDelegate = dataModelInstance.prefs
                    controller.dataModelDelegate = dataModelInstance
                    controller.viewControllerDelegate = self
                } else if let controller = controller as? DonationPreferencesVC {
                    controller.preferencesDelegate = dataModelInstance.prefs
                    controller.iAPHelperDelegate = dataModelInstance.store
                    dataModelInstance.store.donationPreferencesVCDelegate = controller
                }
            }

        } else if let viewController = segue.destinationController as? OnboardingViewController {
            viewController.iAPHelperDelegate = dataModelInstance.store
            viewController.viewControllerDelegate = self
            dataModelInstance.onboardingVCDelegate = viewController
            dataModelInstance.store.onboardingVCDelegate = viewController
        }
    }

    override func keyDown(with event: NSEvent) {

        // key code of "backspace" is "51"
        if event.keyCode == 51,
            let firstResponder = self.view.window?.firstResponder as? NSTableView,
            let identifier = firstResponder.identifier,
            identifier.rawValue == TableView.documentTagsTableView.rawValue {

            // remove the selected tag
            removeSelectedTagFromSelectedDocument()

        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Helper functions

    private func removeSelectedTagFromSelectedDocument() {

        // test if the document tag table is empty
        guard let selectedDocument = dataModelInstance.selectedDocument else {
            return
        }

        // get the selected tags
        let tags = Array(dataModelInstance.selectedDocument?.tags ?? Set()).sorted()

        // validate the table view index
        guard tags.indices.contains(documentTagsTableView.selectedRow) else { return }
        let selectedTag = tags[documentTagsTableView.selectedRow]

        // remove the selected element
        dataModelInstance.remove(tag: selectedTag, from: selectedDocument)

        // update the document attributes
        updateView(.documentAttributes)
    }
}
