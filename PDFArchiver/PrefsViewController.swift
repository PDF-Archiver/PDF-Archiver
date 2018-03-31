//
//  PrefsViewController.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

protocol PrefsViewControllerDelegate: class {
    func setDataModel(dataModel: DataModel)
    func getDataModel() -> DataModel
}

class PrefsViewController: NSViewController {
    var dataModel: DataModel?
    weak var delegate: PrefsViewControllerDelegate?

    @IBOutlet weak var archivePathTextField: NSTextField!

    @IBOutlet weak var observedPathTextField: NSTextField!

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
            self.dataModel?.prefs?.archivePath = openPanel.url!
            self.archivePathTextField.stringValue = openPanel.url!.path
            NotificationCenter.default.post(name: Notification.Name("UpdateViewController"), object: nil)
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
            self.dataModel?.prefs?.observedPath = openPanel.url!
            self.observedPathTextField.stringValue = openPanel.url!.path
            self.dataModel?.addDocuments(paths: openPanel.urls)
            NotificationCenter.default.post(name: Notification.Name("UpdateViewController"), object: nil)
        }
    }

    override func viewWillAppear() {
        self.view.window?.titleVisibility = NSWindow.TitleVisibility.hidden
        self.view.window?.titlebarAppearsTransparent = true
        self.view.window?.styleMask.remove(.resizable)
        self.view.window?.styleMask.insert(.fullSizeContentView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.dataModel = self.delegate?.getDataModel()

        // update path field
        self.dataModel?.prefs!.load()
        if let archivePath = self.dataModel?.prefs?.archivePath {
            self.archivePathTextField.stringValue = archivePath.path
        }
        if let observedPath = self.dataModel?.prefs?.observedPath {
            self.observedPathTextField.stringValue = observedPath.path
        }
    }

    override func viewWillDisappear() {
        // save the current paths + tags
        self.dataModel?.prefs?.save()

        // update the data model of the main view controller
        if let dataModel = self.dataModel {
            self.delegate?.setDataModel(dataModel: dataModel)
        }
    }
}
