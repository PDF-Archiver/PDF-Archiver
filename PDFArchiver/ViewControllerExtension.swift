//
//  ViewControllerExtension.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Quartz

extension ViewController {
    // MARK: - segue stuff
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        // set preferences variable in the PrefsViewController
        if segue.identifier?.rawValue == "prefsSegue" {
            guard let secondVC = segue.destinationController as? PrefsViewController else { return }
            secondVC.prefs = self.dataModelInstance.prefs
        }
    }

    // MARK: - notifications
    @objc func updateViewController(updatePDF: Bool) {
        self.tagAC.content = self.dataModelInstance.tags?.list

        // test if no documents exist in document table view
        if self.dataModelInstance.documents?.count == nil || self.dataModelInstance.documents?.count == 0 {
            self.pdfContentView.document = nil
            self.datePicker.dateValue = Date()
            self.descriptionField.stringValue = ""
            self.documentTagAC.content = nil
            return
        }
        let idx = self.dataModelInstance.documentIdx ?? 0
        let document = self.dataModelInstance.documents![idx] as Document

        // set the document date, description and tags
        self.datePicker.dateValue = document.documentDate ?? Date()
        self.descriptionField.stringValue = document.documentDescription ?? ""
        self.documentTagAC.content = document.documentTags
        self.documentAC.setSelectionIndex(self.dataModelInstance.documentIdx ?? 0)

        // update pdf view
        if updatePDF {
            self.pdfContentView.document = PDFDocument(url: document.path)
            // self.pdfview.displayMode = PDFDisplayMode.singlePageContinuous
            self.pdfContentView.displayMode = PDFDisplayMode.singlePage
            self.pdfContentView.autoScales = false
            self.pdfContentView.acceptsDraggedFiles = false
            self.pdfContentView.interpolationQuality = PDFInterpolationQuality.low
        }
    }
    @objc func showPreferences() {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "prefsSegue"), sender: self)
    }

    @objc func getPDFDocuments() {
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
                for element in openPanel.urls {
                    for pdf_path in getPDFs(url: element) {
                        let selectedDocument = Document(path: pdf_path)
                        self.dataModelInstance.documents?.append(selectedDocument)
                    }
                }
            }
            openPanel.close()

            // add pdf documents to the controller (and replace the old ones)
            self.documentAC.content = self.dataModelInstance.documents
            // no need to refresh the view manually here, because the selection changes which triggers a view update
        }
    }
    @objc func saveDocument() {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty else {
            return
        }
        guard let idx = self.dataModelInstance.documentIdx else { return }
        guard var documents = self.dataModelInstance.documents else { return }
        guard let path = self.dataModelInstance.prefs?.archivePath else { return }
        let result = (documents[idx] as Document).rename(archivePath: path)
        if result {
            self.documentAC.content = documents
            if idx < documents.count {
                self.dataModelInstance.documentIdx = idx + 1
            }
            updateViewController(updatePDF: true)
        }
    }

    // MARK: some helper methods
    func sortArrayController(by key: String, ascending asc: Bool) {
        tagAC.sortDescriptors = [NSSortDescriptor(key: key, ascending: asc)]
        tagAC.rearrangeObjects()
    }
}

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        if let identifier = tableView.identifier, identifier.rawValue == "DocumentTableView" {
            // get the index of the selected row and save it
            self.dataModelInstance.documentIdx = tableView.selectedRow

            // pick a document and save the tags in the document tag list
            self.updateViewController(updatePDF: true)
        }
    }
}

extension ViewController: NSSearchFieldDelegate, NSTextFieldDelegate {
    override func controlTextDidChange(_ notification: Notification) {
        guard let id = notification.object as? NSTextField else { return }
        if id.identifier?.rawValue == "documentDescriptionField" {
            guard let textField = notification.object as? NSTextField else { return }
            guard let idx = self.dataModelInstance.documentIdx else { return }
            (self.dataModelInstance.documents![idx] as Document).documentDescription = textField.stringValue
        } else if id.identifier?.rawValue == "tagSearchField" {
            guard let searchField = notification.object as? NSSearchField else { return }
            let tags = self.dataModelInstance.tags?.filter(prefix: searchField.stringValue)
            self.tagAC.content = tags
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
        let tags = self.tagAC.content as? [Tag] ?? []
        if tags.count > 0 {
            selectedTag = tags.first!
            newlyCreated = false
        } else {
            // no tag selected - get the name of the search field
            selectedTag = Tag(name: self.tagSearchField.stringValue,
                              count: 0)
            newlyCreated = true
        }

        // test if element already exists in document tag table view
        if let documentTags = self.documentTagAC.content as? [Tag] {
            for tag in documentTags where tag.name == selectedTag.name {
                print("Tag already found!")
                return
            }
        }

        // add new tag to document table view
        if let idx = self.dataModelInstance.documentIdx {
            if self.dataModelInstance.documents![idx].documentTags != nil {
                self.dataModelInstance.documents![idx].documentTags!.insert(selectedTag, at: 0)
            } else {
                self.dataModelInstance.documents![idx].documentTags = [selectedTag]
            }

            // clear search field content
            self.tagSearchField.stringValue = ""

            // add tag to tagAC
            if newlyCreated {
                self.dataModelInstance.tags?.list.insert(selectedTag)
            }
            self.updateViewController(updatePDF: false)
        } else {
            print("Please pick documents first!")
        }
    }
}
