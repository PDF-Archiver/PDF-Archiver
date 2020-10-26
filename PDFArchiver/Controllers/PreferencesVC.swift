//
//  PreferencesPanelVC.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 06.04.18.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import Cocoa
import os.log

class PreferencesVC: NSViewController, Logging {

    override func viewWillAppear() {
        super.viewWillAppear()

        view.window?.titlebarAppearsTransparent = true
        view.window?.styleMask.remove(.resizable)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard let title = title else { return }
        parent?.view.window?.title = title
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // resize the view
        preferredContentSize = NSSize(width: view.frame.size.width,
                                      height: view.frame.size.height)
    }
}
