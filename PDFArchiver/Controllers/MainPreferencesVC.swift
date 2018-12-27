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
    weak var dataModelDelegate: DataModelDelegate?

    @IBOutlet weak var useiCloudDrive: NSButton!
    @IBOutlet weak var archivePathTextField: NSTextField!
    @IBOutlet weak var changeArchivePathButton: NSButton!
    @IBOutlet weak var observedPathTextField: NSTextField!
    @IBOutlet weak var documentSlugifyCheckButton: NSButton!
    @IBOutlet weak var tagsCheckButton: NSButton!
    @IBOutlet weak var convertPicturesButton: NSButton!

    @IBAction private func iCloudDriveButtonClicked(_ sender: NSButton) {
        preferencesDelegate?.useiCloudDrive = sender.state == .on
        updateArchiveFolderSection()

        // update archived documents, because they might have changed in the new folder
        self.dataModelDelegate?.updateArchivedDocuments()

        // update the tag table view
        self.viewControllerDelegate?.updateView(.tags)
    }

    @IBAction private func changeArchivePathButtonClicked(_ sender: Any) {
        guard let mainWindow = NSApplication.shared.mainWindow else { fatalError("Main Window not found!") }
        let openPanel = getOpenPanel("Choose an archive folder")
        openPanel.beginSheetModal(for: mainWindow) { response in

            guard response == NSApplication.ModalResponse.OK,
                let openPanelUrl = openPanel.url else { return }

            self.archivePathTextField.stringValue = openPanelUrl.path
            self.preferencesDelegate?.archivePath = openPanelUrl

            // update the documents of the new archive
            self.dataModelDelegate?.updateArchivedDocuments()

            // update the tag table view
            self.viewControllerDelegate?.updateView(.tags)
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

            // update the untagged documents
            self.dataModelDelegate?.updateUntaggedDocuments(paths: [openPanelUrl])

            // update observed documents
            self.viewControllerDelegate?.updateView(.documents)
        }
    }

    @IBAction private func documentSlugifyCheckButtonClicked(_ sender: NSButton) {
        preferencesDelegate?.slugifyNames = sender.state == .on
    }

    @IBAction private func tagsCheckButtonClicked(_ sender: NSButton) {
        preferencesDelegate?.analyseAllFolders = sender.state == .on

        // update archived documents to get the new tags
        dataModelDelegate?.updateArchivedDocuments()

        // update the tag table view
        viewControllerDelegate?.updateView(.tags)
    }

    @IBAction private func convertPicturesButtonClicked(_ sender: NSButton) {
        preferencesDelegate?.convertPictures = sender.state == .on

        if let observedPath = preferencesDelegate?.observedPath {

            // update and convert pictures
            dataModelDelegate?.updateUntaggedDocuments(paths: [observedPath])

            // update archived documents to get the new tags
            viewControllerDelegate?.updateView(.all)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // update path field
        if let observedPath = preferencesDelegate?.observedPath {
            observedPathTextField.stringValue = observedPath.path
        }

        // document slugify
        documentSlugifyCheckButton.state = (preferencesDelegate?.slugifyNames ?? true) ? .on : .off

        // update tags
        tagsCheckButton.state = (preferencesDelegate?.analyseAllFolders ?? false) ? .on : .off

        // convert pictures
        convertPicturesButton.state = (preferencesDelegate?.convertPictures ?? false) ? .on : .off

        updateArchiveFolderSection()
    }

    override func viewWillDisappear() {
        // save the current paths + tags
        dataModelDelegate?.savePreferences()
    }

    private func updateArchiveFolderSection() {
        if let archivePath = preferencesDelegate?.archivePath {
            archivePathTextField.stringValue = archivePath.path
        }

        if preferencesDelegate?.iCloudDrivePath != nil {
            useiCloudDrive.state = (preferencesDelegate?.useiCloudDrive ?? false) ? .on : .off
        } else {
            useiCloudDrive.state = .off
            useiCloudDrive.isEnabled = false
        }

        archivePathTextField.isEnabled = !(preferencesDelegate?.useiCloudDrive ?? false)
        changeArchivePathButton.isEnabled = !(preferencesDelegate?.useiCloudDrive ?? false)
    }
}
