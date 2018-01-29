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

    @IBAction func showPreferences(_ sender: Any) {
        NotificationCenter.default.post(name: Notification.Name("ShowPreferences"), object: nil)
    }
    @IBAction func getPDFDocuments(_ sender: Any) {
        NotificationCenter.default.post(name: Notification.Name("GetPDFDocuments"), object: nil)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
}
