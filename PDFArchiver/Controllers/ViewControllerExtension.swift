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
        if let tabViewController = segue.destinationController as? NSTabViewController {
            for controller in tabViewController.childViewControllers {
                if let controller = controller as? MainPreferencesVC {
                    controller.preferencesDelegate = self.dataModelInstance.prefs
                } else if let controller = controller as? DonationPreferencesVC {
                    controller.preferencesDelegate = self.dataModelInstance.prefs
                    controller.iAPHelperDelegate = self.dataModelInstance.store
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

    func setDocuments(documents: [Document]) {
        self.documentAC.content = documents
    }

    func closeApp() {
        NSApplication.shared.terminate(self)
    }

    func updateView(updatePDF: Bool) {
        os_log("Update view controller fields and tables.", log: self.log, type: .debug)
        self.tagAC.content = self.dataModelInstance.tags

        // test if no documents exist in document table view
        if self.dataModelInstance.archive.documents.count == 0 {
            self.pdfContentView.document = nil
            self.datePicker.dateValue = Date()
            self.specificationField.stringValue = ""
            self.documentTagAC.content = nil
            return
        }
        if let selectedDocument = self.documentAC.selectedObjects.first as? Document {
            // set the document date, description and tags
            self.datePicker.dateValue = selectedDocument.date
            self.specificationField.stringValue = selectedDocument.specification ?? ""
            self.documentTagAC.content = selectedDocument.documentTags

            // access the file system and update pdf view
            if updatePDF {
                self.dataModelInstance.prefs.accessSecurityScope {
                    self.pdfContentView.document = PDFDocument(url: selectedDocument.path)
                    self.pdfContentView.goToFirstPage(self)
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

            var description = textField.stringValue.lowercased()
            if self.dataModelInstance.prefs.slugifyNames {
                description = description.slugify()
            }
            selectedDocument.specification = description

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

        // add new tag to document table view
        guard let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
                os_log("Please pick documents first!", log: self.log, type: .info)
                return
        }

        // try to get the selected tag
        var selectedTag: Tag
        let tags = self.tagAC.arrangedObjects as? [Tag] ?? []
        if tags.count > 0 {
            selectedTag = tags.first!
        } else {
            // no tag selected - get the name of the search field
            var tagName = self.tagSearchField.stringValue.lowercased()
            if self.dataModelInstance.prefs.slugifyNames {
                tagName = tagName.slugify()
            }
            selectedTag = Tag(name: tagName,
                              count: 1)
            self.dataModelInstance.tags.insert(selectedTag)
        }

        // add the selected tag to the document
        self.dataModelInstance.add(tag: selectedTag, to: selectedDocument)
    }
}
