//
//  PreferencesPanelVC.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 06.04.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import os.log

class PreferencesVC: NSViewController, Logging {

    override func viewWillAppear() {
        super.viewWillAppear()

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
