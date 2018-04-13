//
//  DonationPreferencesVC.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 06.04.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import StoreKit

//public typealias ProductsRequestCompletionHandler = (_ success: Bool, _ products: [SKProduct]?) -> Void

class DonationPreferencesVC: PreferencesVC {
    @IBOutlet weak var subscriptionLevel1Button: NSButton!
    var dataModel: DataModel?
    weak var delegate: PreferencesDelegate?

    var productsRequestCompletionHandler: ProductsRequestCompletionHandler?

    override func viewDidLoad() {
        super.viewDidLoad()

        // get the data model from the main view controller
        self.dataModel = self.delegate?.getDataModel()
    }

    @IBAction func subscriptionLevel1Clicked(_ sender: NSButton) {
//        self.dataModel?.store.requestProducts {success, products in
//            if success {
//                print(products)
//            }
//        }
        print(self.dataModel?.store.products)
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
