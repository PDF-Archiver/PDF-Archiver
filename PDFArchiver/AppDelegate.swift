//
//  AppDelegate.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.12.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Keys
import os.log
import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "PDFArchiver", category: "AppDelegate")

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        DispatchQueue.global().async {
            // start IAP service
            _ = IAP.service

            // start document service
            _ = DocumentService.archive
            _ = DocumentService.documentsQuery
        }

        // Create a Sentry client and start crash handler
        do {
            Client.shared = try Client(dsn: PDFArchiverKeys().sentryDSN)
            try Client.shared?.startCrashHandler()
            Client.shared?.enableAutomaticBreadcrumbTracking()
            Client.shared?.trackMemoryPressureAsEvent()
        } catch let error {
            os_log("%@", log: AppDelegate.log, type: .error, error.localizedDescription)
        }

        window?.tintColor = .paDarkGray
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.paDarkGray]

        Log.info("Application did finish launching.")

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Log.info("Application did entry background.")
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        Log.info("Application did receive memory warning.")
    }
}
