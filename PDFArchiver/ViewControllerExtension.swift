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
        guard let tabViewController = segue.destinationController
            as? NSTabViewController else { return }

        for controller in tabViewController.childViewControllers {
            if let controller = controller as? MainPreferencesVC {
                controller.delegate = self
            } else if let controller = controller as? DonationPreferencesVC {
                controller.delegate = self
            }
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
            if updatePDF {
                self.accessSecurityScope {
                    self.pdfContentView.document = PDFDocument(url: selectedDocument.path)
                    self.pdfContentView.goToFirstPage(self)
                }
            }
        }
    }

    func setObservedPath() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose an observed folder"
        openPanel.showsResizeIndicator = false
        openPanel.showsHiddenFiles = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            guard response == NSApplication.ModalResponse.OK else { return }
            self.dataModelInstance.prefs.observedPath = openPanel.url!
            self.dataModelInstance.addDocuments(paths: openPanel.urls)

            // get tags and update the GUI
            self.dataModelInstance.updateTags {
                self.updateGUI()
            }
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
        self.accessSecurityScope {
            let result = selectedDocument.rename(archivePath: path)

            if result {
                // update the array controller
                self.documentAC.content = self.dataModelInstance.documents

                // select a new document, which is not already done
                var newIndex = 0
                var documents = (self.documentAC.arrangedObjects as? [Document]) ?? []
                for idx in 0...documents.count-1 where documents[idx].documentDone == "" {
                    newIndex = idx
                    break
                }
                self.documentAC.setSelectionIndex(newIndex)
            }
        }
    }

    func addDocumentTag(tag selectedTag: Tag, new newlyCreated: Bool) {
        // test if element already exists in document tag table view
        if let documentTags = self.documentTagAC.content as? [Tag] {
            for tag in documentTags where tag.name == selectedTag.name {
                os_log("Tag '%@' already found!", log: self.log, type: .error, selectedTag.name)
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

    func testArchiveModification() {
        if let archivePath = self.dataModelInstance.prefs.archivePath {
            let fileManager = FileManager.default
            var newArchiveModificationDate: Date?
            do {
                // get the attributes of the current archive folder
                let attributes = try fileManager.attributesOfItem(atPath: archivePath.path)
                newArchiveModificationDate = attributes[FileAttributeKey.modificationDate] as? Date
            } catch let error {
                os_log("Folder not found: %@ \nUpdate tags anyway.", log: self.log, type: .debug, error.localizedDescription)
            }

            // compare dates here
            if let archiveModificationDate = self.dataModelInstance.prefs.archiveModificationDate,
                let newArchiveModificationDate = newArchiveModificationDate,
                archiveModificationDate == newArchiveModificationDate {
                os_log("No changes in archive folder, skipping tag update.", log: self.log, type: .debug)

            } else {
                os_log("Changes in archive folder detected, update tags.", log: self.log, type: .debug)

                // get tags and update the GUI
                self.dataModelInstance.updateTags {
                    self.updateGUI()
                }
            }
        }
    }
}

// MARK: - Selection changes in a NSTableView
extension ViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let identifier = (notification.object as? NSTableView)?.identifier?.rawValue,
           identifier == "DocumentTableView" {
            self.updateView(updatePDF: true)
        }
    }
}

// MARK: - Selection changes in the description or search field
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

        // update GUI
        self.updateView(updatePDF: false)
    }
}

// MARK: - custom delegates
extension ViewController: ViewControllerDelegate {
    func setDocuments(documents: [Document]) {
        self.documentAC.content = documents
    }

    func accessSecurityScope(closure: () -> Void) {
        // start accessing the file system
        // TODO: use the closure if needed
        if !(self.dataModelInstance.prefs.observedPath?.startAccessingSecurityScopedResource() ?? false) {
            os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
            //                    return
        }
        // TODO: only access the security scope, if the documents need it
        if !(self.dataModelInstance.prefs.archivePath?.startAccessingSecurityScopedResource() ?? false) {
            os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
            //                    return
        }

        // run the used code
        closure()

        // stop accessing the file system
        self.dataModelInstance.prefs.archivePath?.stopAccessingSecurityScopedResource()
        self.dataModelInstance.prefs.observedPath?.stopAccessingSecurityScopedResource()
    }
}

extension ViewController: PreferencesDelegate {
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
