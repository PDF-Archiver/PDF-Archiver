//
//  AppDelegate.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

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
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
