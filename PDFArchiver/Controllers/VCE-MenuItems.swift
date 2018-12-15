//
//  VCE-MenuItems.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 23.05.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import os.log
import Quartz

// MARK: - Menu Items
extension ViewController {

    // MARK: - PDF Archiver Menu
    @IBAction private func showPreferencesMenuItem(_ sender: NSMenuItem) {
        self.performSegue(withIdentifier: "prefsSegue", sender: self)
    }

    // MARK: - Window Menu
    @IBAction private func zoomPDFMenuItem(_ sender: NSMenuItem) {
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
    @IBAction private func deleteDocumentMenuItem(_ sender: NSMenuItem) {
        // select the document which should be deleted
        guard let selectedDocument = dataModelInstance.selectedDocument else {
                return
        }

        // get the index of selected document
        let idx = self.documentTableView.selectedRow

        // move the document to trash
        // TODO: feedback if the document can not be trashed
        _ = self.dataModelInstance.trashDocument(selectedDocument)

        // update the GUI
        if idx < dataModelInstance.sortedDocuments.count {
            self.documentTableView.selectRowIndexes(IndexSet([idx]), byExtendingSelection: false)
        } else {
            self.documentTableView.selectRowIndexes(IndexSet([dataModelInstance.sortedDocuments.count - 1]), byExtendingSelection: false)
        }
    }

    // MARK: - Help Menu

    @IBAction private func showHelp(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.faq.url)
    }

    @IBAction private func showPrivacy(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.privacy.url)
    }

    @IBAction private func showImprint(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.imprint.url)
    }

    @IBAction private func showOnboardingMenuItem(_ sender: AnyObject) {
        self.performSegue(withIdentifier: "onboardingSegue", sender: self)
    }

    @IBAction private func updateViewMenuItem(_ sender: AnyObject) {

        // update files in the observed path
        if let observedPath = self.dataModelInstance.prefs.observedPath {
            self.dataModelInstance.updateUntaggedDocuments(paths: [observedPath])
        }

        // get tags and update the GUI
        self.updateView(.all)
    }

    @IBAction private func showManageSubscriptions(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.manageSubscription)
    }

    @IBAction private func writeAppStoreReview(_ sender: NSMenuItem) {
        AppStoreReviewRequest.shared.requestReviewManually(for: Constants.appId)
    }

    @IBAction private func resetCacheMenuItem(_ sender: NSMenuItem) {
        // remove all user defaults
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { fatalError("Bundle Identifiert not found.") }
        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)

        // remove preferences - initialize it temporary and kill the app directly afterwards
        self.dataModelInstance.prefs = Preferences()

        // close application
        NSApplication.shared.terminate(self)
    }
}
