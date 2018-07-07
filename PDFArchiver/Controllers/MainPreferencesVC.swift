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
    @IBOutlet weak var documentSlugifyCheckButton: NSButton!
    @IBOutlet weak var tagsCheckButton: NSButton!
    @IBOutlet weak var convertPicturesButton: NSButton!

    @IBAction func changeArchivePathButton(_ sender: Any) {
        let openPanel = getOpenPanel("Choose an archive folder")
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            guard response == NSApplication.ModalResponse.OK else { return }
            self.dataModel?.prefs.archivePath = openPanel.url!
            self.archivePathTextField.stringValue = openPanel.url!.path

            // get tags and update the GUI
            self.dataModel?.updateTags {
                self.delegate?.updateGUI()
            }
        }
    }

    @IBAction func changeObservedPathButton(_ sender: NSButton) {
        let openPanel = getOpenPanel("Choose an observed folder")
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            guard response == NSApplication.ModalResponse.OK else { return }
            self.observedPathTextField.stringValue = openPanel.url!.path
            self.dataModel?.prefs.observedPath = openPanel.url!
            self.dataModel?.addDocuments(paths: openPanel.urls)

            // get tags and update the GUI
            self.dataModel?.updateTags {
                self.delegate?.updateGUI()
            }
        }
    }

    @IBAction func documentSlugifyCheckButtonClicked(_ sender: NSButton) {
        self.dataModel?.prefs.slugifyNames = sender.state == .on
    }

    @IBAction func tagsCheckButtonClicked(_ sender: NSButton) {
        self.dataModel?.prefs.analyseAllFolders = sender.state == .on

        // get tags and update the GUI
        self.dataModel?.updateTags {
            self.delegate?.updateGUI()
        }
    }
    @IBAction func convertPicturesButtonClicked(_ sender: NSButton) {
        self.dataModel?.prefs.convertPictures = sender.state == .on
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

        // document slugify
        self.documentSlugifyCheckButton.state = (self.dataModel?.prefs.slugifyNames ?? true) ? .on : .off

        // update tags
        self.tagsCheckButton.state = (self.dataModel?.prefs.analyseAllFolders ?? false) ? .on : .off

        // convert pictures
        self.convertPicturesButton.state = (self.dataModel?.prefs.convertPictures ?? false) ? .on : .off
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
