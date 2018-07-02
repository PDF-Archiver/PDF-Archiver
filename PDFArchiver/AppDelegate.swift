//
//  AppDelegate.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import os.log

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    fileprivate let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")

    @IBAction func showHelp(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(URL(string: "https://pdf-archiver.io/faq")!)
    }
    @IBAction func showPrivacy(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(URL(string: NSLocalizedString("privacy", comment: "PDF Archiver privacy website"))!)
    }
    @IBAction func showImprint(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(URL(string: NSLocalizedString("imprint", comment: "PDF Archiver imprint website"))!)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Test whether the app's receipt exists.
        // from: https://developer.apple.com/library/archive/technotes/tn2259/_index.html
        if let url = Bundle.main.appStoreReceiptURL, let _ = try? Data(contentsOf: url) {
            // The receipt exists. Do something.
            os_log("Receipt found.", log: self.log, type: .debug)
        } else {
            // Validation fails. The receipt does not exist.
            os_log("Receipt not found, exit the app!", log: self.log, type: .error)
            exit(173)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
