//
//  PrefsViewController.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class MainPreferencesVC: PreferencesVC {
    weak var preferencesDelegate: PreferencesDelegate?
    weak var viewControllerDelegate: ViewControllerDelegate?

    @IBOutlet weak var archivePathTextField: NSTextField!
    @IBOutlet weak var observedPathTextField: NSTextField!
    @IBOutlet weak var documentSlugifyCheckButton: NSButton!
    @IBOutlet weak var tagsCheckButton: NSButton!
    @IBOutlet weak var convertPicturesButton: NSButton!

    @IBAction func changeArchivePathButton(_ sender: Any) {
        let openPanel = getOpenPanel("Choose an archive folder")
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            guard response == NSApplication.ModalResponse.OK else { return }
            self.preferencesDelegate?.archivePath = openPanel.url!
            self.archivePathTextField.stringValue = openPanel.url!.path
            self.viewControllerDelegate?.updateView(updatePDF: false)
        }
    }

    @IBAction func changeObservedPathButton(_ sender: NSButton) {
        let openPanel = getOpenPanel("Choose an observed folder")
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            guard response == NSApplication.ModalResponse.OK else { return }
            self.observedPathTextField.stringValue = openPanel.url!.path
            self.preferencesDelegate?.observedPath = openPanel.url!
            // no need to update the view here - it gets updated automatically, when documents are added
        }
    }

    @IBAction func documentSlugifyCheckButtonClicked(_ sender: NSButton) {
        self.preferencesDelegate?.slugifyNames = sender.state == .on
    }

    @IBAction func tagsCheckButtonClicked(_ sender: NSButton) {
        self.preferencesDelegate?.analyseAllFolders = sender.state == .on
    }
    @IBAction func convertPicturesButtonClicked(_ sender: NSButton) {
        self.preferencesDelegate?.convertPictures = sender.state == .on
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // update path field
        if let archivePath = self.preferencesDelegate?.archivePath {
            self.archivePathTextField.stringValue = archivePath.path
        }
        if let observedPath = self.preferencesDelegate?.observedPath {
            self.observedPathTextField.stringValue = observedPath.path
        }

        // document slugify
        self.documentSlugifyCheckButton.state = (self.preferencesDelegate?.slugifyNames ?? true) ? .on : .off

        // update tags
        self.tagsCheckButton.state = (self.preferencesDelegate?.analyseAllFolders ?? false) ? .on : .off

        // convert pictures
        self.convertPicturesButton.state = (self.preferencesDelegate?.convertPictures ?? false) ? .on : .off
    }

    override func viewWillDisappear() {
        // save the current paths + tags
        self.preferencesDelegate?.save()
    }
}
