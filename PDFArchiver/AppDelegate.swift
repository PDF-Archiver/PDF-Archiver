//
//  AppDelegate.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.12.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Keys
import LogModel
import os.log
import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "PDFArchiver", category: "AppDelegate")

    var window: UIWindow?

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

        Log.send(.info, "Handling shared document", extra: ["filetype": url.pathExtension])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = url.startAccessingSecurityScopedResource()
                try StorageHelper.handle(url)
                url.stopAccessingSecurityScopedResource()
            } catch let error {
                url.stopAccessingSecurityScopedResource()
                Log.send(.error, "Unable to handle file.", extra: ["filetype": url.pathExtension, "error": error.localizedDescription])
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent())

                DispatchQueue.main.async {
                    let alert = UIAlertController(error, preferredStyle: .alert)
                    self.window?.rootViewController?.present(alert, animated: true, completion: nil)
                }
            }
        }

        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        DispatchQueue.global().async {

            // start logging service by sending old events (if needed)
            Log.sendOrPersistInBackground(application)

            // start IAP service
            _ = IAP.service

            // start document service
            _ = DocumentService.archive
            _ = DocumentService.documentsQuery
        }

        // Create a Sentry client and start crash handler
        do {
            Client.shared = try Client(options: [
                "dsn": PDFArchiverKeys().sentryDSN,
                "environment": AppEnvironment.get().rawValue,
                "release": AppEnvironment.getFullVersion()
            ])
            try Client.shared?.startCrashHandler()
            Client.shared?.enableAutomaticBreadcrumbTracking()
            Client.shared?.trackMemoryPressureAsEvent()

            // I am not interested in this kind of data
            Client.shared?.beforeSerializeEvent = { event in
                event.fingerprint = nil
                event.context?.deviceContext?["storage_size"] = nil
                event.context?.deviceContext?["free_memory"] = nil
                event.context?.deviceContext?["memory_size"] = nil
                event.context?.deviceContext?["boot_time"] = nil
                event.context?.deviceContext?["timezone"] = nil
                event.context?.deviceContext?["usable_memory"] = nil
                event.context?.appContext?["device_app_hash"] = nil
                event.context?.appContext?["app_id"] = nil
            }

        } catch let error {
            os_log("%@", log: AppDelegate.log, type: .error, error.localizedDescription)
        }

        window?.tintColor = .paDarkGray
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.paDarkGray]

        return true
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        Log.send(.warning, "Did receive memory warning.")
    }

    func applicationWillResignActive(_ application: UIApplication) {

        // send logs in background
        Log.sendOrPersistInBackground(application)
    }
}
