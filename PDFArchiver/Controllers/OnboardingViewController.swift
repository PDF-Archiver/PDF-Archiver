//
//  OnboardingViewController.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 28.02.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class OnboardingViewController: NSViewController {
    weak var delegate: PreferencesDelegate?
    var dataModel: DataModel?

    @IBOutlet weak var customView: NSView!
    @IBOutlet weak var monthlySubscriptionButton: NSButton!
    @IBOutlet weak var yearlySubscriptionButton: NSButton!

    @IBAction func monthlySubscriptionButtonClicked(_ sender: NSButton) {
    }

    @IBAction func yearlySubscriptionButton(_ sender: NSButton) {
        print(self.dataModel)
    }

    @IBAction func closeButton(_ sender: NSButton) {
        self.dismiss(self)

        // TODO: test if user has not purchased the app
        self.delegate?.closeApp()

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do view setup here.
//        UserDefaults.standard.set(true, forKey: "onboardingShown")

        // get the data model from the main view controller
        self.dataModel = self.delegate?.getDataModel()
    }

    override func viewWillAppear() {
        // set background color of the view
        self.customView.wantsLayer = true
        self.customView.layer?.backgroundColor = NSColor(named: NSColor.Name("OffWhite"))!.cgColor
    }
}
