//
//  ViewControllerExtension.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Quartz
import os.log

extension ViewController {
    // MARK: - segue stuff
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        // preferences view controller delegate
        if let prefsViewController = segue.destinationController as? PrefsViewController {
            prefsViewController.delegate = self
        }
    }

    // MARK: - notifications
    @objc func updateViewController(updatePDF: Bool) {
        os_log("Update view controller fields and tables.", log: self.log, type: .debug)
        self.tagAC.content = self.dataModelInstance.tags

        // test if no documents exist in document table view
        if self.dataModelInstance.documents?.count == nil || self.dataModelInstance.documents?.count == 0 {
            self.pdfContentView.document = nil
            self.datePicker.dateValue = Date()
            self.descriptionField.stringValue = ""
            self.documentTagAC.content = nil
            return
        }
        if let selectedDocument = self.dataModelInstance.selectedDocument {
            // set the document date, description and tags
            self.datePicker.dateValue = selectedDocument.documentDate
            self.descriptionField.stringValue = selectedDocument.documentDescription ?? ""
            self.documentTagAC.content = selectedDocument.documentTags

            // update pdf view
            if updatePDF {
                self.pdfContentView.document = PDFDocument(url: selectedDocument.path)
            }
        }
    }
    @objc func showPreferences() {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "prefsSegue"), sender: self)
    }
    @objc func resetCache() {
        // remove preferences
        self.dataModelInstance.prefs = nil
        // remove all user defaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        // close application
        NSApplication.shared.terminate(self)
    }
    @objc func showOnboarding() {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "onboardingSegue"), sender: self)
    }
    @objc func updateTags() {
        os_log("Setting archive path, e.g. update tag list.", log: self.log, type: .debug)
        self.dataModelInstance.prefs?.getArchiveTags()
    }
    func getPDFDocuments() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose a .pdf file or a folder"
        openPanel.showsResizeIndicator = false
        openPanel.showsHiddenFiles = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedFileTypes = ["pdf"]
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { (response) in
            if response.rawValue == NSApplication.ModalResponse.OK.rawValue {
                // clear old documents from view
                self.dataModelInstance.documents = []

                // get the new documents
                self.dataModelInstance.addDocuments(paths: openPanel.urls)
            }
            openPanel.close()

            // add pdf documents to the controller (and replace the old ones)
            self.documentAC.content = self.dataModelInstance.documents
            // no need to refresh the view manually here, because the selection changes which triggers a view update
        }
    }
    func saveDocument() {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty,
              let selectedDocument = self.dataModelInstance.selectedDocument,
              let documents = self.dataModelInstance.documents else {
            return
        }

        guard let path = self.dataModelInstance.prefs?.archivePath else {
            dialogOK(messageKey: "no_archive", infoKey: "select_preferences", style: .critical)
            return
        }
        let result = selectedDocument.rename(archivePath: path)
        if result {
            // select a new document
            self.documentAC.content = documents
            self.updateViewController(updatePDF: true)
        }
    }
    func addDocumentTag(tag selectedTag: Tag, new newlyCreated: Bool) {
        // test if element already exists in document tag table view
        if let documentTags = self.documentTagAC.content as? [Tag] {
            for tag in documentTags where tag.name == selectedTag.name {
                os_log("Tag '%@' already found!", log: self.log, type: .error, selectedTag.name as CVarArg)
                return
            }
        }

        // add new tag to document table view
        guard let selectedDocument = self.dataModelInstance.selectedDocument else {
            os_log("Please pick documents first!", log: self.log, type: .info)
            return
        }

        if selectedDocument.documentTags != nil {
            selectedDocument.documentTags!.insert(selectedTag, at: 0)
        } else {
            selectedDocument.documentTags = [selectedTag]
        }

        // clear search field content
        self.tagSearchField.stringValue = ""

        // add tag to tagAC
        if newlyCreated {
            self.dataModelInstance.tags?.insert(selectedTag)
        }
        self.updateViewController(updatePDF: false)
    }
}

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        if let identifier = tableView.identifier,
           identifier.rawValue == "DocumentTableView",
           tableView.selectedRow >= 0 {
            // get the index of the selected row and save it
            self.dataModelInstance.selectedDocument = self.documentAC.selectedObjects.first as? Document

            // pick a document and save the tags in the document tag list
            self.updateViewController(updatePDF: true)
        }
    }
}

extension ViewController: NSSearchFieldDelegate, NSTextFieldDelegate {
    override func controlTextDidChange(_ notification: Notification) {
        guard let identifier = (notification.object as? NSTextField)?.identifier else { return }
        if identifier.rawValue == "documentDescriptionField" {
            guard let textField = notification.object as? NSTextField,
                  let selectedDocument = self.dataModelInstance.selectedDocument else { return }
            selectedDocument.documentDescription = textField.stringValue
        } else if identifier.rawValue == "tagSearchField" {
            guard let searchField = notification.object as? NSSearchField else { return }
            self.tagAC.content = self.dataModelInstance.filterTags(prefix: searchField.stringValue)
        }
    }

    override func controlTextDidEndEditing(_ notification: Notification) {
        // check if the last key pressed is the Return key
        guard let textMovement = notification.userInfo?["NSTextMovement"] as? Int else { return }
        if textMovement != NSReturnTextMovement.hashValue {
            return
        }

        // try to get the selected tag
        var selectedTag: Tag
        let newlyCreated: Bool
        let tags = self.tagAC.arrangedObjects as? [Tag] ?? []
        if tags.count > 0 {
            selectedTag = tags.first!
            selectedTag.count += 1
            newlyCreated = false
        } else {
            // no tag selected - get the name of the search field
            selectedTag = Tag(name: slugifyTag(self.tagSearchField.stringValue),
                              count: 1)
            newlyCreated = true
        }

        // add the selected tag to the document
        self.addDocumentTag(tag: selectedTag, new: newlyCreated)
    }
}

extension ViewController: PrefsViewControllerDelegate {
    func setDataModel(dataModel: DataModel) {
        self.dataModelInstance = dataModel
    }

    func getDataModel() -> DataModel {
        return self.dataModelInstance
    }
}
