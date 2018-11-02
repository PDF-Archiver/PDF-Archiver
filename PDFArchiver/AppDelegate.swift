//
//  AppDelegate.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import Sentry

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create a Sentry client and start crash handler
        do {
            Client.shared = try Client(dsn: "https://c37dadbfbc6040d2bd2ebcc0c1fd9e3d@sentry.io/1300124")
            try Client.shared?.startCrashHandler()
            Client.shared?.enableAutomaticBreadcrumbTracking()
        } catch let error {
            print("\(error)")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
