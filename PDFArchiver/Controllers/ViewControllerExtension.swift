//
//  ViewControllerExtension.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import Quartz

extension ViewController {
    // MARK: - segue stuff
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let tabViewController = segue.destinationController as? NSTabViewController {
            for controller in tabViewController.children {
                if let controller = controller as? MainPreferencesVC {
                    controller.preferencesDelegate = self.dataModelInstance.prefs
                    controller.viewControllerDelegate = self
                } else if let controller = controller as? DonationPreferencesVC {
                    controller.preferencesDelegate = self.dataModelInstance.prefs
                    controller.iAPHelperDelegate = self.dataModelInstance.store
                    self.dataModelInstance.store.donationPreferencesVCDelegate = controller
                }
            }

        } else if let viewController = segue.destinationController as? OnboardingViewController {
            viewController.iAPHelperDelegate = self.dataModelInstance.store
            viewController.viewControllerDelegate = self
            self.dataModelInstance.onboardingVCDelegate = viewController
            self.dataModelInstance.store.onboardingVCDelegate = viewController
        }
    }
}

// MARK: - view controller delegates
extension ViewController: ViewControllerDelegate {

    func clearTagSearchField() {
        self.tagSearchField.stringValue = ""
    }

    func closeApp() {
        NSApplication.shared.terminate(self)
    }

    func updateView(updatePDF: Bool) {
        os_log("Update view controller fields and tables.", log: self.log, type: .debug)

        // test if no documents exist in document table view
        if self.dataModelInstance.untaggedDocuments.isEmpty {
            self.pdfContentView.document = nil
            self.datePicker.dateValue = Date()
            self.specificationField.stringValue = ""
            self.documentTagAC.content = nil
            return
        }
        if let selectedDocument = getSelectedDocument() {
            // set the document date, description and tags
            self.datePicker.dateValue = selectedDocument.date
            self.specificationField.stringValue = selectedDocument.specification
            self.documentTagAC.content = selectedDocument.tags

            // access the file system and update pdf view
            if updatePDF {
                self.dataModelInstance.prefs.accessSecurityScope {
                    self.pdfContentView.document = PDFDocument(url: selectedDocument.path)
                    self.pdfContentView.goToFirstPage(self)
                }
            }
        }

        // TODO: where is this function called? reload changes selection
//        documentTableView.reloadData()
//        tagTableView.reloadData()
//        documentTagsTableView.reloadData()
    }
}

// MARK: - Selection changes in a NSTableView

extension ViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView.identifier?.rawValue == "DocumentTableView" {
            return self.dataModelInstance.untaggedDocuments.count
//        } else if tableView.identifier?.rawValue == "DocumentTagsTableView" {
            // TODO: this should be document specific
//            return self.dataModelInstance.filteredTags.count
        } else if tableView.identifier?.rawValue == "TagsTableView" {
            return self.dataModelInstance.tagManager.getPresentedTags().count
        } else {
            return 0
        }
    }

    //    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
    //        guard let sortDescriptor = tableView.sortDescriptors.first else {
    //            return
    //        }
    //
    //        if let order = Directory.FileOrder(rawValue: sortDescriptor.key!) {
    //            sortOrder = order
    //            sortAscending = sortDescriptor.ascending
    //            reloadFileList()
    //        }
    //    }

}

extension ViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let identifier = (notification.object as? NSTableView)?.identifier?.rawValue,
           identifier == "DocumentTableView" {
            self.updateView(updatePDF: true)
        }
    }

    fileprivate enum CellIdentifiers: String {
        case documentStatusCell
        case documentNameCell
        case documentTagCell
        case tagCountCell
        case tagNameCell
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        // TODO: remove this debug code
        if let id = tableView.identifier?.rawValue,
            id != "DocumentTableView" {
            print(id)
        }

        var text: String = ""
        var cellIdentifier: CellIdentifiers?

        if tableView.identifier?.rawValue == "DocumentTableView" {
            guard row < self.dataModelInstance.untaggedDocuments.count  else { return nil }
            let document = self.dataModelInstance.untaggedDocuments[row]

            if tableColumn == tableView.tableColumns[0] {
                cellIdentifier = .documentStatusCell
                let alreadyRenamed = document.path.hasParent(self.dataModelInstance.prefs.archivePath)
                text = alreadyRenamed ? "✔︎" : ""

            } else if tableColumn == tableView.tableColumns[1] {
                cellIdentifier = .documentNameCell
                text = document.filename
            }

        } else if tableView.identifier?.rawValue == "DocumentTagsTableView" {
            guard row < dataModelInstance.tagManager.getPresentedTags().count  else { return nil }
            let tag = dataModelInstance.tagManager.getPresentedTags()[row]

            cellIdentifier = .documentTagCell
            text = tag.name

        } else if tableView.identifier?.rawValue == "TagsTableView" {
            guard row < dataModelInstance.tagManager.getPresentedTags().count  else { return nil }
            let tag = dataModelInstance.tagManager.getPresentedTags()[row]

            if tableColumn == tableView.tableColumns[0] {
                cellIdentifier = .tagCountCell
                text = String(tag.count)
            } else if tableColumn == tableView.tableColumns[1] {
                cellIdentifier = .tagNameCell
                text = tag.name
            }
        }

        if let cellIdentifier = cellIdentifier,
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier.rawValue), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        } else {
            return nil
        }
    }
}

// MARK: - Selection changes in the description or search field
extension ViewController: NSSearchFieldDelegate, NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        guard let identifier = (notification.object as? NSTextField)?.identifier else { return }
        if identifier.rawValue == "documentDescriptionField" {
            guard let textField = notification.object as? NSTextField,
                  let selectedDocument = getSelectedDocument() else { return }

            selectedDocument.specification = textField.stringValue.lowercased()

        } else if identifier.rawValue == "tagSearchField" {
            guard let searchField = notification.object as? NSSearchField else { return }
            self.dataModelInstance.tagManager.filterTags(prefix: searchField.stringValue)
            self.tagTableView.reloadData()
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        // check if notification comes from the tagSearchField
        guard let field = notification.object as? NSSearchField,
              field.identifier?.rawValue == "tagSearchField" else { return }

        // check if the last key pressed is the Return key
        guard let textMovement = notification.userInfo?["NSTextMovement"] as? Int else { return }
        if textMovement != NSReturnTextMovement {
            return
        }

        // add new tag to document table view
        guard let selectedDocument = getSelectedDocument() else {
                os_log("Please pick documents first!", log: self.log, type: .info)
                return
        }

        // try to get the selected tag
        var selectedTag: Tag
        let tags = self.dataModelInstance.tagManager.getPresentedTags()
        if !tags.isEmpty,
            let firstTag = tags.first {
            selectedTag = firstTag
        } else {
            // no tag selected - get the name of the search field
            var tagName = self.tagSearchField.stringValue   // the string gets normalized in the Tag() constructor
            if self.dataModelInstance.prefs.slugifyNames {
                tagName = tagName.slugify()
            }
            selectedTag = self.dataModelInstance.tagManager.addTagWith(tagName)
        }

        // add the selected tag to the document
        self.dataModelInstance.add(tag: selectedTag, to: selectedDocument)
    }
}
