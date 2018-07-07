//
//  DonationPreferencesVC.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 06.04.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import StoreKit
import Foundation
import os.log

class DonationPreferencesVC: PreferencesVC {
    @IBOutlet weak var donationNumberLabel: NSTextField!
    @IBOutlet weak var donationButton1: NSButton!
    @IBOutlet weak var donationButton2: NSButton!
    @IBOutlet weak var donationButton3: NSButton!
    @IBOutlet weak var donationButton: NSButton!

    private var donationsNumber = "0"
    weak var preferencesDelegate: PreferencesDelegate?
    weak var iAPHelperDelegate: IAPHelperDelegate?

    @IBAction func donationButton1Clicked(_ sender: NSButton) {
        self.iAPHelperDelegate?.buyProduct("DONATION_LEVEL1")
    }

    @IBAction func donationButton2Clicked(_ sender: NSButton) {
        self.iAPHelperDelegate?.buyProduct("DONATION_LEVEL2")
    }

    @IBAction func donationButton3Clicked(_ sender: NSButton) {
        self.iAPHelperDelegate?.buyProduct("DONATION_LEVEL3")
    }

    @IBAction func statusImageClicked(_ sender: Any) {
        if connectedToNetwork(),
           self.iAPHelperDelegate?.products.isEmpty ?? true {
            self.iAPHelperDelegate?.requestProducts()
        }
    }

    override func viewWillAppear() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(self.masUpdateStatus(available:)),
                                       name: Notification.Name("MASUpdateStatus"), object: nil)

        // set the status image
        if self.iAPHelperDelegate?.products.isEmpty ?? true {
            self.donationButton.image = NSImage(named: .statusUnavailable)
        } else {
            self.donationButton.image = NSImage(named: .statusAvailable)
        }

        // update the buttons
        DispatchQueue.main.async {
            self.updateButtons()
        }

        // update the donation count property
        DispatchQueue.global().async {
            self.donationsNumber = getNumberOfDonations()
        }
    }

    // TODO: things should be saved when the MainPrefsVC disappears
//    override func viewWillDisappear() {
//        // save the current paths + tags
//        self.preferencesDelegate?.save()
//    }

    @objc func masUpdateStatus(available: Bool) {
        DispatchQueue.main.async {
            if available {
                self.donationButton.image = NSImage(named: .statusAvailable)
            } else {
                self.donationButton.image = NSImage(named: .statusUnavailable)
            }

            self.updateButtons()
        }
    }

    func updateButtons() {
        // set the button label
        for product in self.iAPHelperDelegate?.products ?? [] {
            var selectedButton: NSButton

            switch product.productIdentifier {
            case "DONATION_LEVEL1":
                selectedButton = self.donationButton1
            case "DONATION_LEVEL2":
                selectedButton = self.donationButton2
            case "DONATION_LEVEL3":
                selectedButton = self.donationButton3
            default:
                continue
            }

            // set button to localized price
            selectedButton.title = product.localizedPrice
            selectedButton.isEnabled = true
        }

        // update the number of donations
        self.donationNumberLabel.stringValue = "\(self.donationsNumber) \(NSLocalizedString("donation_number_label", comment: "Donation Number label"))"
    }
}
