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

    @IBOutlet weak var useiCloudDrive: NSButton!
    @IBOutlet weak var archivePathTextField: NSTextField!
    @IBOutlet weak var changeArchivePathButton: NSButton!
    @IBOutlet weak var observedPathTextField: NSTextField!
    @IBOutlet weak var documentSlugifyCheckButton: NSButton!
    @IBOutlet weak var tagsCheckButton: NSButton!
    @IBOutlet weak var convertPicturesButton: NSButton!

    @IBAction private func iCloudDriveButtonClicked(_ sender: NSButton) {
        self.preferencesDelegate?.useiCloudDrive = sender.state == .on
        self.updateArchiveFolderSection()
    }

    @IBAction private func changeArchivePathButtonClicked(_ sender: Any) {
        guard let mainWindow = NSApplication.shared.mainWindow else { fatalError("Main Window not found!") }
        let openPanel = getOpenPanel("Choose an archive folder")
        openPanel.beginSheetModal(for: mainWindow) { response in

            guard response == NSApplication.ModalResponse.OK,
                let openPanelUrl = openPanel.url else { return }

            self.archivePathTextField.stringValue = openPanelUrl.path
            self.preferencesDelegate?.archivePath = openPanelUrl
            self.viewControllerDelegate?.updateView(updatePDF: false)
        }
    }

    @IBAction private func changeObservedPathButtonClicked(_ sender: NSButton) {
        guard let mainWindow = NSApplication.shared.mainWindow else { fatalError("Main Window not found!") }
        let openPanel = getOpenPanel("Choose an observed folder")
        openPanel.beginSheetModal(for: mainWindow) { response in

            guard response == NSApplication.ModalResponse.OK,
                let openPanelUrl = openPanel.url else { return }

            self.observedPathTextField.stringValue = openPanelUrl.path
            self.preferencesDelegate?.observedPath = openPanelUrl
            // no need to update the view here - it gets updated automatically, when documents are added
        }
    }

    @IBAction private func documentSlugifyCheckButtonClicked(_ sender: NSButton) {
        self.preferencesDelegate?.slugifyNames = sender.state == .on
    }

    @IBAction private func tagsCheckButtonClicked(_ sender: NSButton) {
        self.preferencesDelegate?.analyseAllFolders = sender.state == .on
    }
    @IBAction private func convertPicturesButtonClicked(_ sender: NSButton) {
        self.preferencesDelegate?.convertPictures = sender.state == .on
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // update path field
        if let observedPath = self.preferencesDelegate?.observedPath {
            self.observedPathTextField.stringValue = observedPath.path
        }

        // document slugify
        self.documentSlugifyCheckButton.state = (self.preferencesDelegate?.slugifyNames ?? true) ? .on : .off

        // update tags
        self.tagsCheckButton.state = (self.preferencesDelegate?.analyseAllFolders ?? false) ? .on : .off

        // convert pictures
        self.convertPicturesButton.state = (self.preferencesDelegate?.convertPictures ?? false) ? .on : .off

        self.updateArchiveFolderSection()
    }

    override func viewWillDisappear() {
        // save the current paths + tags
        self.preferencesDelegate?.save()
    }

    private func updateArchiveFolderSection() {
        if let archivePath = self.preferencesDelegate?.archivePath {
            self.archivePathTextField.stringValue = archivePath.path
        }

        if self.preferencesDelegate?.iCloudDrivePath != nil {
            self.useiCloudDrive.state = (self.preferencesDelegate?.useiCloudDrive ?? false) ? .on : .off
        } else {
            self.useiCloudDrive.state = .off
            self.useiCloudDrive.isEnabled = false
        }

        self.archivePathTextField.isEnabled = !(self.preferencesDelegate?.useiCloudDrive ?? false)
        self.changeArchivePathButton.isEnabled = !(self.preferencesDelegate?.useiCloudDrive ?? false)
    }
}
