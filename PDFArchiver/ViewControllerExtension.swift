//
//  ViewControllerExtension.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import Quartz

// Die Extension implementiert das SomeProtocol protokoll.
// Die im Protokoll definierten Funktionen müssen hier implementiert werden.
//extension ViewController: DocumentDelegate {
//    
//    func getDocumentDate() -> Date {
//        return datePicker.dateValue
//    }
//    
//    func getDocumentDescription() -> String {
//        return descriptionField.stringValue
//    }
//    
//}

extension ViewController {
    func updateDocumentFields() {
        let idx: Int = (self.dataModelInstance?.document_idx)!
        let document = self.dataModelInstance!.documents![idx] as Document
        
        // set the document date, description and tags
        self.datePicker.dateValue = document.pdf_date!
        self.descriptionField.stringValue = document.pdf_description!
        self.documentTagAC.content = document.pdf_tags
        
        // update pdf view
        self.pdfview.document = PDFDocument(url: document.path)
        // self.pdfview.displayMode = PDFDisplayMode.singlePageContinuous
        self.pdfview.displayMode = PDFDisplayMode.singlePage
        self.pdfview.autoScales = true
        self.pdfview.acceptsDraggedFiles = false
        self.pdfview.interpolationQuality = PDFInterpolationQuality.low
    }
    
    //MARK: segue stuff
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        // set preferences variable in the PrefsViewController
        if segue.identifier?.rawValue == "prefsSegue" {
            let secondVC = segue.destinationController as! PrefsViewController
            secondVC.prefs = self.dataModelInstance?.prefs
        }
    }
    
    @objc func showPreferences() {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "prefsSegue"), sender: self)
    }
    
    @objc func getPDFDocuments() {
        let selectedDocuments = getOpenPanelFiles()
        // add pdf documents to the controller (and replace the old ones)
        self.dataModelInstance?.documents = selectedDocuments
        self.documentAC.content = self.dataModelInstance?.documents
    }

    //MARK: some helper methods
    func refresh_tags() {
//        let tags_dict = UserDefaults.standard.dictionary(forKey: "tags")!
//        
//        var tags = [Tag]()
//        for (name, count) in tags_dict {
//            tags.append(Tag(name: name, count: count as! Int))
//        }
//        self.sortArrayController(by: "count", ascending: false)
//        self.tagAC.content = self.dataModelInstance?.old_tags
//        self.tagTableView.deselectRow(tagAC.selectionIndex)
    }
      
    func sortArrayController(by key : String, ascending asc : Bool) {
        tagAC.sortDescriptors = [NSSortDescriptor(key: key, ascending: asc)]
        tagAC.rearrangeObjects()
    }
    
//    func savePreferences(prefs: Preferences) {
//        self.prefs = prefs
//    }
    
}

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        if let identifier = tableView.identifier, identifier.rawValue == "DocumentTableView" {
            // get the index of the selected row and save it
            self.dataModelInstance?.document_idx = tableView.selectedRow
            
            // pick a document and save the tags in the document tag list
            updateDocumentFields()
        }
    }
}

extension ViewController: NSSearchFieldDelegate {
    override func controlTextDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSSearchField else { return }
        let tags = self.dataModelInstance?.tags?.filter(prefix: textView.stringValue)
        self.tagAC.content = tags
    }
    
    override func controlTextDidEndEditing(_ notification: Notification) {
        // try to get the selected tag
        var selectedTag: Tag?
        selectedTag = (self.tagAC.content as! [Tag]).first
        if selectedTag == nil {
            // no tag selected - get the name of the search field
            selectedTag = Tag(name: self.tagSearchField.stringValue,
                              count: 0)
        }
        
        // test if element already exists in document tag table view
        for element in self.documentTagAC.arrangedObjects as! [Tag] {
            if element.name == selectedTag?.name {
                return
            }
        }
        
        // add new tag to document table view
        if let idx = self.dataModelInstance!.document_idx {
            // TODO: WTF? do I really have to do this in 2 steps???
            var tmp = self.documentTagAC.content as! [Tag]
            tmp.append(selectedTag!)
            self.documentTagAC.content = tmp
            
            self.dataModelInstance!.documents![idx].pdf_tags!.append(selectedTag!)
        }
    }
}


