//
//  FileHandling.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import os.log
import Quartz

func getOpenPanel(_ title: String) -> NSOpenPanel {
    let openPanel = NSOpenPanel()
    openPanel.title = title
    openPanel.showsResizeIndicator = false
    openPanel.showsHiddenFiles = false
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.canCreateDirectories = true
    return openPanel
}
