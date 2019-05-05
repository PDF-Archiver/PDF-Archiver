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
        } catch let error {
            os_log("%@", log: AppDelegate.log, type: .error, error.localizedDescription)
        }

        self.window?.tintColor = .paDarkGray
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.paDarkGray]

        return true
    }
}
