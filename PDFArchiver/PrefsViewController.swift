//
//  PrefsViewController.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class PrefsViewController: NSViewController {
    var prefs: Preferences?

    @IBOutlet weak var archivePathTextField: NSTextField!
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

            self.prefs!.save()
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

        // update path field
        self.prefs?.load()
        if let archivePath = self.prefs?.archivePath {
            self.archivePathTextField.stringValue = archivePath.path
        }

    }

}
