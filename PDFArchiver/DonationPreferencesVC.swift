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
    @IBOutlet weak var donationButton1: NSButton!
    @IBOutlet weak var donationButton2: NSButton!
    @IBOutlet weak var donationButton3: NSButton!
    @IBOutlet weak var donationButton: NSButton!

    var dataModel: DataModel?
    weak var delegate: PreferencesDelegate?
    var productsRequestCompletionHandler: ProductsRequestCompletionHandler?

    @IBAction func donationButton1Clicked(_ sender: NSButton) {
        self.buyProduct(identifier: "DONATION_LEVEL1")
    }

    @IBAction func donationButton2Clicked(_ sender: NSButton) {
        self.buyProduct(identifier: "DONATION_LEVEL2")
    }

    @IBAction func donationButton3Clicked(_ sender: NSButton) {
        self.buyProduct(identifier: "DONATION_LEVEL3")
    }

    @IBAction func statusImageClicked(_ sender: Any) {
        if connectedToNetwork(),
           self.dataModel?.store.products.isEmpty ?? true {
            self.dataModel?.updateMASStatus()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(self.masUpdateStatus(available:)),
                                       name: Notification.Name("MASUpdateStatus"), object: nil)

        // get the data model from the main view controller
        self.dataModel = self.delegate?.getDataModel()
        self.updateButtons()

        // set the status image
        if self.dataModel?.store.products.isEmpty ?? true {
            self.donationButton.image = NSImage(named: .statusUnavailable)
        } else {
            self.donationButton.image = NSImage(named: .statusAvailable)
        }
    }

    override func viewWillDisappear() {
        // save the current paths + tags
        self.dataModel?.prefs.save()

        // update the data model of the main view controller
        if let dataModel = self.dataModel {
            self.delegate?.setDataModel(dataModel: dataModel)
        }
    }

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
        // set default button status to false
        self.donationButton1.isEnabled = false
        self.donationButton2.isEnabled = false
        self.donationButton3.isEnabled = false

        // set the button label
        for product in self.dataModel?.store.products ?? [] {
            var selectedButton: NSButton
            if product.productIdentifier == "DONATION_LEVEL1" {
                selectedButton = self.donationButton1
            } else if product.productIdentifier == "DONATION_LEVEL2" {
                selectedButton = self.donationButton2
            } else if product.productIdentifier == "DONATION_LEVEL3" {
                selectedButton = self.donationButton3
            } else {
                continue
            }

            // set button to localized price
            selectedButton.title = product.localizedPrice
            selectedButton.isEnabled = true
        }
    }

    func buyProduct(identifier: String) {
        guard let products = self.dataModel?.store.products else { return }
        for product in products where product.productIdentifier == identifier {
            os_log("Button clicked to buy: %@", log: self.log, type: .debug, product.description)
            self.dataModel?.store.buyProduct(product)
            break
        }
    }
}
