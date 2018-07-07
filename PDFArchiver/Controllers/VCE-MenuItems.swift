//
//  VCE-MenuItems.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 23.05.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Quartz
import os.log

// MARK: - Menu Items
extension ViewController {

    // MARK: - PDF Archiver Menu
    @IBAction func showPreferencesMenuItem(_ sender: NSMenuItem) {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "prefsSegue"), sender: self)
    }

    // MARK: - Window Menu
    @IBAction func zoomPDFMenuItem(_ sender: NSMenuItem) {
        guard let identifierName = sender.identifier?.rawValue  else { return }

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

    // MARK: - Edit Menu
    @IBAction func deleteDocumentMenuItem(_ sender: NSMenuItem) {
        // select the document which should be deleted
        guard !self.documentAC.selectedObjects.isEmpty,
            let selectedDocument = self.documentAC.selectedObjects.first as? Document else {
                return
        }

        // move the document to trash
        // TODO: feedback if the document can not be trashed
        _ = self.dataModelInstance.trashDocument(selectedDocument)

        // update the GUI
        self.documentAC.selectNext(self)
        if let idx = self.dataModelInstance.archive.documents.index(where: { $0 == selectedDocument }) {
            self.dataModelInstance.archive.documents.remove(at: idx)
        }
        self.documentAC.content = self.dataModelInstance.archive.documents
    }

    // MARK: - Help Menu
    @IBAction func showOnboardingMenuItem(_ sender: AnyObject) {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "onboardingSegue"), sender: self)
    }

    @IBAction func updateTagsMenuItem(_ sender: AnyObject) {
        os_log("Setting archive path, e.g. update tag list.", log: self.log, type: .debug)

        // get tags and update the GUI
        self.dataModelInstance.updateTags()
        self.updateView(updatePDF: true)
    }

    @IBAction func resetCacheMenuItem(_ sender: NSMenuItem) {
        // remove preferences - initialize it temporary and kill the app directly afterwards
        self.dataModelInstance.prefs = Preferences()
        // remove all user defaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        // close application
        NSApplication.shared.terminate(self)
    }
}
