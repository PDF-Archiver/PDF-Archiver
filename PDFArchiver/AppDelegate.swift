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

    @IBAction func showManageSubscriptions(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.manageSubscription)
    }

    @IBAction func showHelp(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.faq.url)
    }

    @IBAction func showPrivacy(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.privacy.url)
    }

    @IBAction func showImprint(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Constants.WebsiteEndpoints.imprint.url)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
