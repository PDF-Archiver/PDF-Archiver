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
        self.performSegue(withIdentifier: "prefsSegue", sender: self)
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

        // get the index of selected document
        let idx = self.documentAC.selectionIndex

        // move the document to trash
        // TODO: feedback if the document can not be trashed
        _ = self.dataModelInstance.trashDocument(selectedDocument)

        // update the GUI
        if idx < self.dataModelInstance.untaggedDocuments.count {
            self.documentAC.setSelectionIndex(idx)
        } else {
            self.documentAC.setSelectionIndex(self.dataModelInstance.untaggedDocuments.count - 1)
        }
    }

    // MARK: - Help Menu

    @IBAction func showHelp(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.faq.url)
    }

    @IBAction func showPrivacy(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.privacy.url)
    }

    @IBAction func showImprint(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.imprint.url)
    }

    @IBAction func showOnboardingMenuItem(_ sender: AnyObject) {
        self.performSegue(withIdentifier: "onboardingSegue", sender: self)
    }

    @IBAction func updateViewMenuItem(_ sender: AnyObject) {
        // get tags and update the GUI
        self.updateView(updatePDF: true)
    }

    @IBAction func showManageSubscriptions(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.manageSubscription)
    }

    @IBAction func writeAppStoreReview(_ sender: NSMenuItem) {
        AppStoreReviewRequest.shared.requestReviewManually(for: Constants.appId)
    }

    @IBAction func resetCacheMenuItem(_ sender: NSMenuItem) {
        // remove all user defaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)

        // remove preferences - initialize it temporary and kill the app directly afterwards
        self.dataModelInstance.prefs = Preferences()

        // close application
        NSApplication.shared.terminate(self)
    }
}
