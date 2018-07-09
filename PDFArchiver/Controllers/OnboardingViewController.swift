//
//  OnboardingViewController.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 28.02.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

protocol OnboardingVCDelegate: class {
    func updateGUI()
    func closeOnboardingView()
}

class OnboardingViewController: NSViewController {
    weak var iAPHelperDelegate: IAPHelperDelegate?
    weak var viewControllerDelegate: ViewControllerDelegate?

    @IBOutlet weak var baseView: NSView!
    @IBOutlet weak var customView1: NSView!
    @IBOutlet weak var customView2: NSView!
    @IBOutlet weak var customView3: NSView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var lockIndicator: NSImageView!
    @IBOutlet weak var monthlySubscriptionButton: NSButton!
    @IBOutlet weak var yearlySubscriptionButton: NSButton!

    @IBAction func privacyButton(_ sender: NSButton) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.privacy.url)
    }

    @IBAction func restorePurchasesButton(_ sender: NSButton) {
        self.iAPHelperDelegate?.restorePurchases()
    }

    @IBAction func monthlySubscriptionButtonClicked(_ sender: NSButton) {
        self.iAPHelperDelegate?.buyProduct("SUBSCRIPTION_MONTHLY")
    }

    @IBAction func yearlySubscriptionButton(_ sender: NSButton) {
        self.iAPHelperDelegate?.buyProduct("SUBSCRIPTION_YEARLY")
    }
    @IBAction func manageSubscriptionsButtonClicked(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "https://apps.apple.com/account/subscriptions")!)
    }

    @IBAction func closeButton(_ sender: NSButton?) {
        self.dismiss(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do view setup here.
        UserDefaults.standard.set(true, forKey: "onboardingShown")

        // update the GUI
        self.updateGUI()
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
    }

    override func viewWillDisappear() {
        // test if user has purchased the app, close if not
        if !(self.iAPHelperDelegate?.appUsagePermitted() ?? false) {
            self.viewControllerDelegate?.closeApp()
        }
    }
}

// MARK: - OnboardingVCDelegate

extension OnboardingViewController: OnboardingVCDelegate {
    func updateGUI() {
        DispatchQueue.main.async {
            // update the locked/unlocked indicator
            if let appUsagePermitted = self.iAPHelperDelegate?.appUsagePermitted(),
                appUsagePermitted {
                self.lockIndicator.image = NSImage(named: NSImage.Name("NSLockUnlockedTemplate"))

            } else {
                self.lockIndicator.image = NSImage(named: NSImage.Name("NSLockLockedTemplate"))

                // update the progress indicator
                if (self.iAPHelperDelegate?.requestRunning ?? 0) != 0 {
                    self.progressIndicator.startAnimation(self)
                } else {
                    self.progressIndicator.stopAnimation(self)
                }
            }

            // set the button label
            for product in self.iAPHelperDelegate?.products ?? [] {
                var selectedButton: NSButton

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

                // enable the button
                if !(self.iAPHelperDelegate?.preSubscriptionPurchase() ?? false) {
                    selectedButton.isEnabled = true
                }
            }
        }
    }

    func closeOnboardingView() {
        DispatchQueue.main.async {
            self.closeButton(nil)
        }
    }
}
