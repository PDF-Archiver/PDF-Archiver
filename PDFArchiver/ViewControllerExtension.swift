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
            let secondVC = segue.destinationController as! PrefsViewController
            secondVC.prefs = self.dataModelInstance.prefs
        }
    }
    
    // MARK: - notifications
    @objc func updateViewController(update_pdf: Bool) {
        self.tagAC.content = self.dataModelInstance.tags?.list
        
        // test if no documents exist in document table view
        if self.dataModelInstance.documents?.count == nil || self.dataModelInstance.documents?.count == 0 {
            self.pdfview.document = nil
            self.datePicker.dateValue = Date()
            self.descriptionField.stringValue = ""
            self.documentTagAC.content = nil
            return
        }
        let idx = self.dataModelInstance.document_idx ?? 0
        let document = self.dataModelInstance.documents![idx] as Document
        
        // set the document date, description and tags
        self.datePicker.dateValue = document.pdf_date ?? Date()
        self.descriptionField.stringValue = document.pdf_description ?? ""
        self.documentTagAC.content = document.pdf_tags
        
        // update pdf view
        if update_pdf {
            self.pdfview.document = PDFDocument(url: document.path)
            // self.pdfview.displayMode = PDFDisplayMode.singlePageContinuous
            self.pdfview.displayMode = PDFDisplayMode.singlePage
            self.pdfview.autoScales = false
            self.pdfview.acceptsDraggedFiles = false
            self.pdfview.interpolationQuality = PDFInterpolationQuality.low
        }
    }
    @objc func showPreferences() {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "prefsSegue"), sender: self)
    }
    
    @objc func getPDFDocuments() {
        let selectedDocuments = getOpenPanelFiles()
        // add pdf documents to the controller (and replace the old ones)
        self.dataModelInstance.documents = selectedDocuments
        self.documentAC.content = self.dataModelInstance.documents
    }
    @objc func saveDocument() {
        // test if a document is selected
        guard !self.documentAC.selectedObjects.isEmpty else {
            return
        }
        guard let idx = self.dataModelInstance.document_idx else { return }
        guard var documents = self.dataModelInstance.documents else { return }
        guard let path = self.dataModelInstance.prefs?.archivePath else { return }
        let result = (documents[idx] as Document).rename(archive_path: path)
        if result {
            documents.remove(at: self.dataModelInstance.document_idx!)
            self.documentAC.content = documents
            updateViewController(update_pdf: true)
        }
    }

    //MARK: some helper methods
    func sortArrayController(by key : String, ascending asc : Bool) {
        tagAC.sortDescriptors = [NSSortDescriptor(key: key, ascending: asc)]
        tagAC.rearrangeObjects()
    }
}

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        if let identifier = tableView.identifier, identifier.rawValue == "DocumentTableView" {
            // get the index of the selected row and save it
            self.dataModelInstance.document_idx = tableView.selectedRow
            
            // pick a document and save the tags in the document tag list
            self.updateViewController(update_pdf: true)
        }
    }
}

extension ViewController: NSSearchFieldDelegate, NSTextFieldDelegate {
    override func controlTextDidChange(_ notification: Notification) {
        let id = notification.object as! NSTextField
        if id.identifier?.rawValue == "documentDescriptionField" {
            guard let textField = notification.object as? NSTextField else { return }
            guard let idx = self.dataModelInstance.document_idx else { return }
            (self.dataModelInstance.documents![idx] as Document).pdf_description = textField.stringValue
        } else if id.identifier?.rawValue == "tagSearchField" {
            guard let searchField = notification.object as? NSSearchField else { return }
            let tags = self.dataModelInstance.tags?.filter(prefix: searchField.stringValue)
            self.tagAC.content = tags
        }
    }
    
    override func controlTextDidEndEditing(_ notification: Notification) {
        var newly_created = false
        
        // try to get the selected tag
        var selectedTag: Tag?
        selectedTag = (self.tagAC.content as! [Tag]).first
        if selectedTag == nil {
            // no tag selected - get the name of the search field
            selectedTag = Tag(name: self.tagSearchField.stringValue,
                              count: 0)
            newly_created = true
        }
        
        // test if element already exists in document tag table view
        for element in self.documentTagAC.arrangedObjects as! [Tag] {
            if element.name == selectedTag?.name {
                return
            }
        }
        
        // add new tag to document table view
        if let idx = self.dataModelInstance.document_idx {
            // TODO: WTF? do I really have to do this in 2 steps???
            var tmp = self.documentTagAC.content as! [Tag]
            tmp.append(selectedTag!)
            self.documentTagAC.content = tmp
            
            if self.dataModelInstance.documents![idx].pdf_tags != nil {
                self.dataModelInstance.documents![idx].pdf_tags!.append(selectedTag!)
            } else {
                self.dataModelInstance.documents![idx].pdf_tags = [selectedTag!]
            }
            
            // clear search field content
            self.tagSearchField.stringValue = ""
            
            // add tag to tagAC
            if newly_created {
                self.dataModelInstance.tags?.list.insert(selectedTag!)
                self.updateViewController(update_pdf: false)
            }
        }
    }
}
