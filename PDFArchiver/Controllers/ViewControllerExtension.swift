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

protocol ViewControllerDelegate: AnyObject {
    func closeApp()
    func updateView(_ options: UpdateOptions)
}

public struct UpdateOptions: OptionSet {
    public let rawValue: Int

    static let documents = UpdateOptions(rawValue: 1 << 0)
    static let documentAttributes = UpdateOptions(rawValue: 1 << 1)
    static let pdfView = UpdateOptions(rawValue: 1 << 2)
    static let tags = UpdateOptions(rawValue: 1 << 3)

    static let selectedDocument: UpdateOptions = [.documentAttributes, .pdfView]
    static let all: UpdateOptions = [.documents, .documentAttributes, .pdfView, .tags]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

// MARK: - view controller delegates
extension ViewController: ViewControllerDelegate {

    func closeApp() {
        NSApplication.shared.terminate(self)
    }

    func updateView(_ options: UpdateOptions) {
        os_log("Update view with option %i", log: log, type: .debug, options.rawValue)

        // test if no documents exist in document table view
        if dataModelInstance.sortedDocuments.isEmpty {
            pdfContentView.document = nil
            datePicker.dateValue = Date()
            specificationField.stringValue = ""
        }

        if options.contains(.documentAttributes),
            let selectedDocument = dataModelInstance.selectedDocument {

            // set the document date, description and tags
            datePicker.dateValue = selectedDocument.date
            specificationField.stringValue = selectedDocument.specification
            documentTagsTableView.reloadData()
        }

        // access the file system and update pdf view
        if options.contains(.pdfView),
            let documentPath = dataModelInstance.selectedDocument?.path {

            try? dataModelInstance.prefs.accessSecurityScope {
                pdfContentView.document = PDFDocument(url: documentPath)
                pdfContentView.goToFirstPage(self)
            }
        }

        // update the document table view
        if options.contains(.documents) {
            documentTableView.reloadData()
        }

        // update the tag table view
        if options.contains(.tags) {
            tagTableView.reloadData()
        }
    }
}

// MARK: - Selection changes in a NSTableView

extension ViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView.identifier?.rawValue == TableView.documentTableView.rawValue {
            return dataModelInstance.sortedDocuments.count
        } else if tableView.identifier?.rawValue == TableView.documentTagsTableView.rawValue {
            return dataModelInstance.selectedDocument?.tags.count ?? 0
        } else if tableView.identifier?.rawValue == TableView.tagsTableView.rawValue {
            return dataModelInstance.sortedTags.count
        } else {
            return 0
        }
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        if tableView.identifier?.rawValue == TableView.documentTableView.rawValue {

            // apply the new sort descriptors to the documents
            dataModelInstance.documentSortDescriptors = tableView.sortDescriptors

            // update the document view
            updateView(.documents)

        } else if tableView.identifier?.rawValue == TableView.tagsTableView.rawValue {

            // apply the new sort descriptors to the tags
            dataModelInstance.tagSortDescriptors = tableView.sortDescriptors

            // update the document view
            updateView(.tags)
        }
    }

}

extension ViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {

        // Use the table selection change only for the documents view.
        // DocumentTagsTableView & TagsTableView should only be updated on a user interaction:
        // * @IBAction private func clickedDocumentTagTableView(_ sender: NSTableView)
        // * @IBAction private func clickedTagTableView(_ sender: NSTableView)
        if let tableView = notification.object as? NSTableView,
            tableView.identifier?.rawValue == TableView.documentTableView.rawValue,
            documentTableView.selectedRow >= 0 {

            // save the new selected document
            dataModelInstance.selectedDocument = dataModelInstance.sortedDocuments[documentTableView.selectedRow]

            // update the view
            updateView(.selectedDocument)
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        var text: String = ""
        var cellIdentifier: CellIdentifiers?

        if tableView.identifier?.rawValue == TableView.documentTableView.rawValue {

            let document = dataModelInstance.sortedDocuments[row]

            if tableColumn == tableView.tableColumns[0] {
                cellIdentifier = .documentStatusCell
                text = document.taggingStatus == .tagged ? "✔︎" : ""

            } else if tableColumn == tableView.tableColumns[1] {
                cellIdentifier = .documentNameCell
                text = document.filename
            }

        } else if tableView.identifier?.rawValue == TableView.documentTagsTableView.rawValue {

            // get the right tag for this cell
            let tag = Array(dataModelInstance.selectedDocument?.tags ?? Set<Tag>()).sorted()[row]

            cellIdentifier = .documentTagCell
            text = tag.name

        } else if tableView.identifier?.rawValue == TableView.tagsTableView.rawValue {

            let tag = dataModelInstance.sortedTags[row]

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
                  let selectedDocument = dataModelInstance.selectedDocument else { return }

            selectedDocument.specification = textField.stringValue.lowercased()

        } else if identifier.rawValue == "tagSearchField" {
            guard let searchField = notification.object as? NSSearchField else { return }
            dataModelInstance.tagFilterTerm = searchField.stringValue
            tagTableView.reloadData()
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

        // try to get the selected tag
        let selectedTagName: String
        let tags = dataModelInstance.sortedTags
        if !tags.isEmpty,
            let firstTag = tags.first {
            selectedTagName = firstTag.name
        } else {
            // no tag selected - get the name of the search field
            var tagName = tagSearchField.stringValue   // the string gets normalized in the Tag() constructor
            if dataModelInstance.prefs.slugifyNames {
                tagName = tagName.slugify()
            }
            selectedTagName = tagName
        }

        // add the selected tag to the document
        dataModelInstance.addTagToSelectedDocument(selectedTagName)

        // clear search field content
        tagSearchField.stringValue = ""
        dataModelInstance.tagFilterTerm = ""

        // update the view
        updateView([.selectedDocument, .tags])
    }
}

// MARK: - fileprivate helpers
private enum CellIdentifiers: String {
    case documentStatusCell
    case documentNameCell
    case documentTagCell
    case tagCountCell
    case tagNameCell
}

private enum TableView: String {
    case documentTableView
    case documentTagsTableView
    case tagsTableView
}
