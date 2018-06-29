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

    @IBOutlet weak var baseView: NSView!
    @IBOutlet weak var customView1: NSView!
    @IBOutlet weak var customView2: NSView!
    @IBOutlet weak var customView3: NSView!
    @IBOutlet weak var monthlySubscriptionButton: NSButton!
    @IBOutlet weak var yearlySubscriptionButton: NSButton!

    @IBAction func monthlySubscriptionButtonClicked(_ sender: NSButton) {
        self.dataModel?.store.buyProduct("SUBSCRIPTION_MONTHLY")
    }

    @IBAction func yearlySubscriptionButton(_ sender: NSButton) {
        print(self.dataModel)
    }

    @IBAction func closeButton(_ sender: NSButton) {
        self.dismiss(self)

        // test if user has purchased the app, close if not
        if !(self.dataModel?.store.appUsagePermitted() ?? false) {
            self.delegate?.closeApp()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do view setup here.
        // TODO: this is debug code
//        UserDefaults.standard.set(true, forKey: "onboardingShown")

        // get the data model from the main view controller
        self.dataModel = self.delegate?.getDataModel()
    }

    override func viewWillAppear() {
        let cornerRadius = CGFloat(3)
        let customViewColor = NSColor(named: NSColor.Name("DarkGreyBlue"))!.withAlphaComponent(0.05).cgColor

        // set background color
        self.baseView.wantsLayer = true
        self.baseView.layer?.backgroundColor = NSColor(named: NSColor.Name("OffWhite"))!.cgColor
        self.baseView.layer?.cornerRadius = cornerRadius

        // set background color of the view
        self.customView1.wantsLayer = true
        self.customView1.layer?.backgroundColor = customViewColor
        self.customView1.layer?.cornerRadius = cornerRadius
        self.customView2.wantsLayer = true
        self.customView2.layer?.backgroundColor = customViewColor
        self.customView2.layer?.cornerRadius = cornerRadius
        self.customView3.wantsLayer = true
        self.customView3.layer?.backgroundColor = customViewColor
        self.customView3.layer?.cornerRadius = cornerRadius

        // set the ui update function
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(self.updateButtons(available:)),
                                       name: Notification.Name("MASUpdateStatus"), object: nil)

    }

    @objc func updateButtons(available: Bool) {
        DispatchQueue.main.async {
            // set default button status to false
            self.monthlySubscriptionButton.isEnabled = false
            self.yearlySubscriptionButton.isEnabled = false

            // set the button label
            for product in self.dataModel?.store.products ?? [] {
                var selectedButton: NSButton

                // TODO: this might be a enum
                switch product.productIdentifier {
                case "SUBSCRIPTION_MONTHLY":
                    selectedButton = self.monthlySubscriptionButton
                    selectedButton.title = product.localizedPrice + " " + NSLocalizedString("per_month", comment: "")

                case "SUBSCRIPTION_YEARLY":
                    selectedButton = self.yearlySubscriptionButton
                    selectedButton.title = product.localizedPrice + " " + NSLocalizedString("per_year", comment: "")

                default:
                    continue
                }

                // set button to localized price
                selectedButton.isEnabled = true
            }

            //
        }
    }
}
