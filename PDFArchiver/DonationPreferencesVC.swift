//
//  DonationPreferencesVC.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 06.04.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import StoreKit

class DonationPreferencesVC: PreferencesVC {
    var dataModel: DataModel?
    weak var delegate: PreferencesDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // get the data model from the main view controller
        self.dataModel = self.delegate?.getDataModel()

        // update path field
        self.dataModel?.prefs.load()
//        if let archivePath = self.dataModel?.prefs.archivePath {
//            self.archivePathTextField.stringValue = archivePath.path
//        }
//        if let observedPath = self.dataModel?.prefs.observedPath {
//            self.observedPathTextField.stringValue = observedPath.path
//        }
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
