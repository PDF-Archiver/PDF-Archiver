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

//public typealias ProductsRequestCompletionHandler = (_ success: Bool, _ products: [SKProduct]?) -> Void

class DonationPreferencesVC: PreferencesVC {
    @IBOutlet weak var statusView: NSImageView!
    @IBOutlet weak var subscriptionLevel1Button: NSButton!
    var dataModel: DataModel?
    weak var delegate: PreferencesDelegate?

    var productsRequestCompletionHandler: ProductsRequestCompletionHandler?

    override func viewDidLoad() {
        super.viewDidLoad()

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
            self.dataModel?.store.requestProducts {success, productss in
                if success {
                    print(productss)
                }
            }
    }

    @IBAction func subscriptionLevel1Clicked(_ sender: NSButton) {
        guard let products = self.dataModel?.store.products else { return }
        for product in self.dataModel?.store.products ?? [] where product.productIdentifier == "SUBSCRIPTION_LEVEL1" {
            self.dataModel?.store.buyProduct(product)
            break
        }
    }
    @IBAction func subscriptionLevel2Clicked(_ sender: NSButton) {
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
