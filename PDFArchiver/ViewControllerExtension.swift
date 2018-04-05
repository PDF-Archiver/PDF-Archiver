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
    @objc func showPreferences() {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "prefsSegue"), sender: self)
    }

    @objc func resetCache() {
        // remove preferences - initialize it temporary and kill the app directly afterwards
        self.dataModelInstance.prefs = Preferences()
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

        // access the file system
        if !(self.dataModelInstance.prefs.archivePath?.startAccessingSecurityScopedResource() ?? false) {
            os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
            return
        }
        self.dataModelInstance.prefs.getArchiveTags()
        self.dataModelInstance.prefs.archivePath?.stopAccessingSecurityScopedResource()
    }

    @objc func zoomPDF(notification: NSNotification) {
        guard let sender = notification.object as? NSMenuItem,
              let identifierName = sender.identifier?.rawValue  else { return }

        if identifierName == "ZoomActualSize" {
            self.pdfContentView.scaleFactor = 1
        } else if identifierName == "ZoomToFit" {
            self.pdfContentView.autoScales = true
        } else if identifierName == "ZoomIn" {
            self.pdfContentView.zoomIn(self)
        } else if identifierName == "ZoomOut" {
            self.pdfContentView.zoomOut(self)
        }
    }

    func updateView(updatePDF: Bool) {
        os_log("Update view controller fields and tables.", log: self.log, type: .debug)
        self.tagAC.content = self.dataModelInstance.tags

        // test if no documents exist in document table view
        if self.dataModelInstance.documents.count == 0 {
            self.pdfContentView.document = nil
            self.datePicker.dateValue = Date()
            self.descriptionField.stringValue = ""
            self.documentTagAC.content = nil
            return
        }
        if let selectedDocument = self.documentAC.selectedObjects.first as? Document {
            // set the document date, description and tags
            self.datePicker.dateValue = selectedDocument.documentDate
            self.descriptionField.stringValue = selectedDocument.documentDescription ?? ""
            self.documentTagAC.content = selectedDocument.documentTags

            // access the file system and update pdf view
            if updatePDF,
               let observedPath = self.dataModelInstance.prefs.observedPath {
                if !observedPath.startAccessingSecurityScopedResource() {
                    os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
                    return
                }
                self.pdfContentView.document = PDFDocument(url: selectedDocument.path)
                observedPath.stopAccessingSecurityScopedResource()
            }
        }
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
              let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
            return
        }

        guard let path = self.dataModelInstance.prefs.archivePath else {
            dialogOK(messageKey: "no_archive", infoKey: "select_preferences", style: .critical)
            return
        }

        // access the file system
        if !(self.dataModelInstance.prefs.archivePath?.startAccessingSecurityScopedResource() ?? false) {
            os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
            return
        }
        if !(self.dataModelInstance.prefs.observedPath?.startAccessingSecurityScopedResource() ?? false) {
            os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
            return
        }
        let result = selectedDocument.rename(archivePath: path)
        self.dataModelInstance.prefs.observedPath?.stopAccessingSecurityScopedResource()
        self.dataModelInstance.prefs.archivePath?.stopAccessingSecurityScopedResource()

        if result {
            // update the array controller
            self.documentAC.content = self.dataModelInstance.documents

            // select a new document
            let newIndex = self.documentAC.selectionIndex + 1
            if newIndex < self.dataModelInstance.documents.count {
                self.documentAC.setSelectionIndex(newIndex)
            } else {
                self.documentAC.setSelectionIndex(0)
            }
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
        guard let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
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
            self.dataModelInstance.tags.insert(selectedTag)
        }
    }
}

extension ViewController: NSSearchFieldDelegate, NSTextFieldDelegate {
    override func controlTextDidChange(_ notification: Notification) {
        guard let identifier = (notification.object as? NSTextField)?.identifier else { return }
        if identifier.rawValue == "documentDescriptionField" {
            guard let textField = notification.object as? NSTextField,
                  let selectedDocument = self.documentAC.selectedObjects.first as? Document else { return }
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
    func updateGUI() {
        self.updateView(updatePDF: true)
    }

    func setDataModel(dataModel: DataModel) {
        self.dataModelInstance = dataModel
    }

    func getDataModel() -> DataModel {
        return self.dataModelInstance
    }
}
