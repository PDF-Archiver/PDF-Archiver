//
//  PDFArchiverApp.swift
//  Shared
//
//  Created by Julian Kahnert on 24.06.20.
//

@_exported import ArchiveBackend
@_exported import ArchiveSharedConstants
@_exported import ArchiveViews

import Diagnostics
import Foundation
import Logging
import Sentry
import SwiftUI

@main
struct PDFArchiverApp: App, Log {

    #if os(macOS)
    //swiftlint:disable:next weak_delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var mainNavigationViewModel = MainNavigationViewModel()

    init() {
        setup()
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            mainView
        }
        // use this when tool bar items were added
        //.windowToolbarStyle(UnifiedCompactWindowToolbarStyle())
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            SidebarCommands()
            CommandGroup(replacing: CommandGroupPlacement.newItem) { }
        }

        Settings {
            SettingsView(viewModel: mainNavigationViewModel.moreViewModel)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        #else
        WindowGroup {
            mainView
        }
        #endif
    }

    private var mainView: some View {
        MainNavigationView(viewModel: mainNavigationViewModel)
            .environmentObject(OrientationInfo())
            .onChange(of: scenePhase) { phase in
                Self.log.info("Scene change: \(phase)")

                #if !APPCLIP && !os(macOS)
                // schedule a new background task
                if phase != .active,
                   mainNavigationViewModel.imageConverter.totalDocumentCount.value > 0 {
                    BackgroundTaskScheduler.shared.scheduleTask(with: .pdfProcessing)
                }
                #endif

                if phase == .active {
                    initializeSentry()
                }
            }
    }

    private func setup() {

        #if os(macOS)
        NSWindow.allowsAutomaticWindowTabbing = false
        #endif

        do {
            try DiagnosticsLogger.setup()
            UserDefaultsReporter.userDefaults = UserDefaults.appGroup
        } catch {
            log.warning("Failed to setup the Diagnostics Logger")
        }

        LoggingSystem.bootstrap { label in
            var sysLogger = StreamLogHandler.standardOutput(label: label)
            sysLogger.logLevel = AppEnvironment.get() == .production ? .info : .trace
            return sysLogger
        }

        DispatchQueue.global().async {

            UserDefaults.runMigration()

            // start document service
            _ = ArchiveStore.shared
        }

        #if !APPCLIP && !os(macOS)
        // background tasks must be initialized before the application did finish launching
        _ = BackgroundTaskScheduler.shared
        #endif

        #if !os(macOS) && DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (_, error) in
                if let error = error {
                    Self.log.errorAndAssert("Failed to get notification authorization", metadata: ["error": "\(error)"])
                }
            }
        }
        #endif
    }

    private func initializeSentry() {
        // Create a Sentry client and start crash handler
        SentrySDK.start { options in
            options.dsn = "https://7adfcae85d8d4b2f946102571b2d4d6c@o194922.ingest.sentry.io/1299590"
            options.environment = AppEnvironment.get().rawValue
            options.releaseName = AppEnvironment.getFullVersion()
            options.enableAutoSessionTracking = AppEnvironment.get() != .production
            options.debug = AppEnvironment.get() != .production

            // Only gets called for the first crash event
            options.onCrashedLastRun = { event in
                log.error("Crash has happened!", metadata: ["event": "\(event)"])
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: self.mainNavigationViewModel.displayUserFeedback)
            }
        }

        SentrySDK.currentHub().getClient()?.options.beforeSend = { event in
            // I am not interested in this kind of data
            event.context?["device"]?["storage_size"] = nil
            event.context?["device"]?["free_memory"] = nil
            event.context?["device"]?["memory_size"] = nil
            event.context?["device"]?["boot_time"] = nil
            event.context?["device"]?["timezone"] = nil
            event.context?["device"]?["usable_memory"] = nil
            return event
        }
    }
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // the app was rejected by apple because a user could not open the app again after closing the main window
        true
    }
}
#endif
