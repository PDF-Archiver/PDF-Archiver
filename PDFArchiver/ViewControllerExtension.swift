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
extension ViewController: DocumentProtocol {
    
    func getDocumentDate() -> Date {
        return datePicker.dateValue
    }
    
    func getDocumentDescription() -> String {
        return descriptionField.stringValue
    }
    
}

extension ViewController {

    func update_PDFView(url: URL) {
        self.pdfview.document = PDFDocument(url: url)
        // self.pdfview.displayMode = PDFDisplayMode.singlePageContinuous
        self.pdfview.displayMode = PDFDisplayMode.singlePage
        self.pdfview.autoScales = true
        self.pdfview.acceptsDraggedFiles = false
        self.pdfview.interpolationQuality = PDFInterpolationQuality.low
    }
    
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
    
//    func update_search_field_tags(search: String) {
//        var tags = [Tag]()
//        for tag in tagAC.arrangedObjects as! [Tag] {
//            if tag.name.hasPrefix(search) {
//                let obj = Tag(name: tag.name, count: 0)
//                tags.append(obj)
//            }
//        }
//        tagAC.content = tags
//        
//    }
    
//    func sortArrayController(by key : String, ascending asc : Bool) {
//        tagAC.sortDescriptors = [NSSortDescriptor(key: key, ascending: asc)]
//        tagAC.rearrangeObjects()
//    }
    
//    func savePreferences(prefs: Preferences) {
//        self.prefs = prefs
//    }
    
}

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        if let identifier = tableView.identifier, identifier.rawValue == "DocumentTableView" {
            // update the PDFView
            let pdf_url = (documentAC.selectedObjects.first as! Document).path
            self.update_PDFView(url: pdf_url)
        }
    }
    
}


