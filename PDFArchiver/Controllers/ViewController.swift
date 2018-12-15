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

protocol ViewControllerDelegate: AnyObject {
    func clearTagSearchField()
    func closeApp()
    func updateView(_ options: UpdateOptions)
}

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
    }

    @IBAction private func descriptionDone(_ sender: NSTextField) {
        // test if a document is selected
        guard let selectedDocument = dataModelInstance.selectedDocument else {
            return
        }

        // set the description of the pdf document
        dataModelInstance.setDocumentDescription(document: selectedDocument, description: sender.stringValue)
    }

    @IBAction private func clickedDocumentTagTableView(_ sender: NSTableView) {

        // test if the document tag table is empty
        guard let selectedDocument = dataModelInstance.selectedDocument else {
                return
        }

        // get the selected tags
        let selectedTag = dataModelInstance.sortedTags[documentTagsTableView.selectedRow]

        // remove the selected element
        dataModelInstance.remove(tag: selectedTag, from: selectedDocument)
    }

    @IBAction private func clickedTagTableView(_ sender: NSTableView) {

        let index = tagTableView.selectedRow
        let selectedTag = dataModelInstance.sortedTags[index]

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

            // reload the data in the table view
            self.documentTableView.reloadData()
        }
    }

    @IBAction private func saveDocumentButton(_ sender: NSButton) {

        guard dataModelInstance.prefs.archivePath != nil else {
            dialogOK(messageKey: "no_archive", infoKey: "select_preferences", style: .critical)
            return
        }

        let result = dataModelInstance.saveDocumentInArchive()

        if result {
            // TODO: is this saving document method correct
//            // select a new document, which is not already done
//            var newIndex = 0
//            var documents = Array(dataModelInstance.archive.get(scope: .all, searchterms: [], status: .untagged))
//            for idx in 0...documents.count - 1 where documents[idx].path.hasParent(dataModelInstance.prefs.archivePath) {
//                newIndex = idx
//                break
//            }
//            documentAC.setSelectionIndex(newIndex)
            let newIndex = documentTableView.selectedRow + 1
            documentTableView.selectRowIndexes(IndexSet([newIndex]), byExtendingSelection: false)
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
        documentTableView.tableColumns[0].sortDescriptorPrototype = NSSortDescriptor(key: DataModel.DocumentOrder.status.rawValue, ascending: true)
        documentTableView.tableColumns[1].sortDescriptorPrototype = NSSortDescriptor(key: DataModel.DocumentOrder.name.rawValue, ascending: true)
        tagTableView.tableColumns[0].sortDescriptorPrototype = NSSortDescriptor(key: DataModel.TagOrder.count.rawValue, ascending: true)
        tagTableView.tableColumns[1].sortDescriptorPrototype = NSSortDescriptor(key: DataModel.TagOrder.name.rawValue, ascending: true)

        documentTableView.sortDescriptors = [NSSortDescriptor(key: "documentDone", ascending: false),
                                                   NSSortDescriptor(key: "name", ascending: true)]
        tagTableView.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false),
                                             NSSortDescriptor(key: "name", ascending: true)]

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
//        documentAC.setSelectionIndex(0)
        documentTableView.selectRowIndexes(IndexSet([0]), byExtendingSelection: false)

        documentTableView.reloadData()
        documentTagsTableView.reloadData()
        tagTableView.reloadData()
    }

//    override func viewWillAppear() {
//        // set the array controller
//        tagAC.content = dataModelInstance.tags
////        documentAC.content = dataModelInstance.untaggedDocuments
//        documentTableView.reloadData()
//    }

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
            // reset the tag count to the archived documents
            for document in dataModelInstance.sortedDocuments where document.path.hasParent(dataModelInstance.prefs.archivePath) {
                for tag in document.tags {
                    tag.count -= 1
                }
            }

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
}
