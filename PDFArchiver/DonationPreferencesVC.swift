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
    @IBOutlet weak var statusView: NSImageView!
    @IBOutlet weak var subscriptionLevel1Button: NSButton!
    var dataModel: DataModel?
    weak var delegate: PreferencesDelegate?
    var productsRequestCompletionHandler: ProductsRequestCompletionHandler?

    override func viewDidLoad() {
        super.viewDidLoad()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(self.masUpdateStatus(available:)),
                                       name: Notification.Name("MASUpdateStatus"), object: nil)

        // get the data model from the main view controller
        self.dataModel = self.delegate?.getDataModel()

        // set the status image
        if self.dataModel?.store.products.isEmpty ?? true {
            self.statusView.image = NSImage(named: .statusUnavailable)
        } else {
            self.statusView.image = NSImage(named: .statusAvailable)
        }
    }

    @IBAction func donationLevel1Clicked(_ sender: NSButton) {
        self.buyProduct(identifier: "DONATION_LEVEL1")
    }

    @IBAction func donationLevel2Clicked(_ sender: NSButton) {
        self.buyProduct(identifier: "DONATION_LEVEL2")
    }

    @IBAction func donationLevel3Clicked(_ sender: NSButton) {
        self.buyProduct(identifier: "DONATION_LEVEL3")
    }

    @IBAction func subscriptionLevel1Clicked(_ sender: NSButton) {
        self.buyProduct(identifier: "SUBSCRIPTION_LEVEL1")
    }

    @IBAction func subscriptionLevel2Clicked(_ sender: NSButton) {
        self.buyProduct(identifier: "SUBSCRIPTION_LEVEL2")
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
                self.statusView.image = NSImage(named: .statusAvailable)
            } else {
                self.statusView.image = NSImage(named: .statusUnavailable)
            }
        }
    }

    func buyProduct(identifier: String) {
        os_log("Button clicked to buy: %@", log: self.log, type: .debug, identifier)

        guard let products = self.dataModel?.store.products else { return }
        for product in products where product.productIdentifier == identifier {
            self.dataModel?.store.buyProduct(product)
            break
        }
    }
}
