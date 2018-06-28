//
//  PreferencesPanelVC.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 06.04.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import os.log

protocol PreferencesDelegate: class {
    func updateGUI()
    func setDataModel(dataModel: DataModel)
    func getDataModel() -> DataModel
    func closeApp()
}

class PreferencesVC: NSViewController {
    internal let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "PreferencesVC")

    override func viewWillAppear() {
        self.view.window?.titlebarAppearsTransparent = true
        self.view.window?.styleMask.remove(.resizable)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        self.parent?.view.window?.title = self.title!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // resize the view
        self.preferredContentSize = NSSize(width: self.view.frame.size.width,
                                           height: self.view.frame.size.height)
    }
}
