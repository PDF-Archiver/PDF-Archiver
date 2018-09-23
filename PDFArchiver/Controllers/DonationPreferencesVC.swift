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

protocol DonationPreferencesVCDelegate: class {
    func updateGUI()
}

class DonationPreferencesVC: PreferencesVC, DonationPreferencesVCDelegate {
    @IBOutlet weak var donationNumberLabel: NSTextField!
    @IBOutlet weak var donationButton1: NSButton!
    @IBOutlet weak var donationButton2: NSButton!
    @IBOutlet weak var donationButton3: NSButton!
    @IBOutlet weak var donationButton: NSButton!

    private var donationsNumber = "0" {
        didSet {
            self.updateGUI()
        }
    }
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

        // update the buttons and use the default donations count
        self.updateGUI()

        // update the donation count property
        DispatchQueue.global().async {
            self.donationsNumber = getNumberOfDonations()
        }
    }

    func updateGUI() {
        DispatchQueue.main.async {

            // set the MAS status image
            if self.iAPHelperDelegate?.products.isEmpty ?? true {
                self.donationButton.image = NSImage(named: "NSStatusUnavailable")
            } else {
                self.donationButton.image = NSImage(named: "NSStatusAvailable")
            }

            // update the donation buttons
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

            // update the donation number
            self.donationNumberLabel.stringValue = "\(self.donationsNumber) \(NSLocalizedString("donation_number_label", comment: "Donation Number label"))"
        }
    }
}
