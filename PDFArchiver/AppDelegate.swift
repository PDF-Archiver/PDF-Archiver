//
//  AppDelegate.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.12.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Diagnostics
import LogModel
import MetricKit
import os.log
import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        MXMetricManager.shared.add(self)
        do {
            try DiagnosticsLogger.setup()
        } catch {
            Log.send(.warning, "Failed to setup the Diagnostics Logger")
        }

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
                "dsn": Constants.sentryDsn,
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
            Log.send(.error, "Error while starting.", extra: ["error": error.localizedDescription])
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

    func applicationWillTerminate(_ application: UIApplication) {
        MXMetricManager.shared.remove(self)
    }
}

extension AppDelegate: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {

            var extra: [String: String] = [:]
            extra["appBuildVersion"] = payload.metaData?.applicationBuildVersion
            extra["osVersion"] = payload.metaData?.osVersion
            extra["regionFormat"] = payload.metaData?.regionFormat
            extra["deviceType"] = payload.metaData?.deviceType
            extra["appVersion"] = payload.latestApplicationVersion
            extra["timeStampBegin"] = payload.timeStampBegin.description
            extra["timeStampEnd"] = payload.timeStampEnd.description
            extra["cumulativeCPUTime"] = payload.cpuMetrics?.cumulativeCPUTime.description
            extra["raw"] = String(data: payload.jsonRepresentation(), encoding: .utf8)

            Log.send(.info, "MXMetricPayload", extra: extra)
        }
    }
}
