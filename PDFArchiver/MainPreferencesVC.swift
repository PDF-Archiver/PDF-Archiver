//
//  PrefsViewController.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class MainPreferencesVC: PreferencesVC {
    var dataModel: DataModel?
    weak var delegate: PreferencesDelegate?

    @IBOutlet weak var archivePathTextField: NSTextField!
    @IBOutlet weak var observedPathTextField: NSTextField!
    @IBOutlet weak var tagsCheckButton: NSButton!

    @IBAction func changeArchivePathButton(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose an archive folder"
        openPanel.showsResizeIndicator = false
        openPanel.showsHiddenFiles = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            guard response == NSApplication.ModalResponse.OK else { return }
            self.dataModel?.prefs.archivePath = openPanel.url!
            self.archivePathTextField.stringValue = openPanel.url!.path

            // update the GUI
            self.delegate?.updateGUI()
        }
    }

    @IBAction func changeObservedPathButton(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose an archive folder"
        openPanel.showsResizeIndicator = false
        openPanel.showsHiddenFiles = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            guard response == NSApplication.ModalResponse.OK else { return }
            self.dataModel?.prefs.observedPath = openPanel.url!
            self.observedPathTextField.stringValue = openPanel.url!.path
            self.dataModel?.addDocuments(paths: openPanel.urls)

            // update the GUI
            self.delegate?.updateGUI()
        }
    }
    @IBAction func tagsCheckButtonClicked(_ sender: NSButton) {
        if sender.state == .on {
            self.dataModel?.prefs.analyseAllFolders = true
        } else {
            self.dataModel?.prefs.analyseAllFolders = false
        }

        // get tags and update GUI
        self.dataModel?.prefs.getArchiveTags()
        self.delegate?.updateGUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // get the data model from the main view controller
        self.dataModel = self.delegate?.getDataModel()

        // update path field
        if let archivePath = self.dataModel?.prefs.archivePath {
            self.archivePathTextField.stringValue = archivePath.path
        }
        if let observedPath = self.dataModel?.prefs.observedPath {
            self.observedPathTextField.stringValue = observedPath.path
        }

        // update tags
        if !(self.dataModel?.prefs.analyseAllFolders ?? false) {
            self.tagsCheckButton.state = .off
        } else {
            self.tagsCheckButton.state = .on
        }
    }

    override func viewWillDisappear() {
        // save the current paths + tags
        self.dataModel?.prefs.save()

        // update the data model of the main view controller
        if let dataModel = self.dataModel {
            self.delegate?.setDataModel(dataModel: dataModel)
        }
    }
}
