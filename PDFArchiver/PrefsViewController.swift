//
//  PrefsViewController.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

protocol PrefsViewControllerDelegate: class {
    func setPrefs(prefs: Preferences)
    func getPrefs() -> Preferences
    func addDocuments(path: URL)
}

class PrefsViewController: NSViewController {
    var prefs: Preferences?
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
            self.prefs?.archivePath = openPanel.url!
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
            self.prefs?.observedPath = openPanel.url!
            self.observedPathTextField.stringValue = openPanel.url!.path
            self.delegate?.addDocuments(path: openPanel.url!)
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
        self.prefs = self.delegate?.getPrefs()

        // update path field
        self.prefs!.load()
        if let archivePath = self.prefs?.archivePath {
            self.archivePathTextField.stringValue = archivePath.path
        }
        if let observedPath = self.prefs?.observedPath {
            self.observedPathTextField.stringValue = observedPath.path
        }
    }

    override func viewWillDisappear() {
        self.delegate?.setPrefs(prefs: self.prefs!)
    }
}
