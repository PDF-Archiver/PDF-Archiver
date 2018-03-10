//
//  AppDelegate.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBAction func showPreferences(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: Notification.Name("ShowPreferences"), object: nil)
    }
    @IBAction func resetUserDefaults(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: Notification.Name("ResetCache"), object: nil)
    }
    @IBAction func showOnboarding(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: Notification.Name("ShowOnboarding"), object: nil)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
