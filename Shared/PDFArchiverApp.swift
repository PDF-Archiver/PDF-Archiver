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

    // swiftlint:disable weak_delegate
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif
    // swiftlint:enable weak_delegate
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
        // .windowToolbarStyle(UnifiedCompactWindowToolbarStyle())
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
                    #if !os(macOS)
                    if let type = shortcutItemToProcess?.type,
                       let itemType = ShortCutItemType(rawValue: type) {
                        switch itemType {
                        case .scan:
                            mainNavigationViewModel.showScan(shareAfterScan: false)
                        case .scanAndShare:
                            mainNavigationViewModel.showScan(shareAfterScan: true)
                        }
                    }
                    // reset the quick action item after handling it during app start
                    shortcutItemToProcess = nil
                    #endif
                } else if phase == .background {
                    #if !os(macOS)
                    // add quick actions
                    UIApplication.shared.shortcutItems = ShortCutItemType.allCases.map(\.item).reversed()
                    #endif
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
//            let logLevel: Logger.Level = AppEnvironment.get() == .production ? .info : .trace
            let logLevel: Logger.Level = .trace
            var sysLogger = StreamLogHandler.standardOutput(label: label)
            sysLogger.logLevel = logLevel
            let sentryLogger = SentryBreadcrumbLogger(metadata: [:], logLevel: logLevel)
            return MultiplexLogHandler([sysLogger, sentryLogger])
        }

        DispatchQueue.global().async {

            UserDefaults.runMigration()

            // start document service
            _ = ArchiveStore.shared
        }

        #if !APPCLIP && !os(macOS)
        // disable transparent UITabBar on iOS 15+
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }

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
            options.enabled = AppEnvironment.get() != .production
            options.enableAutoSessionTracking = AppEnvironment.get() != .production
            options.debug = AppEnvironment.get() != .production

            options.enableCrashHandler = true

            // Only gets called for the first crash event
            options.onCrashedLastRun = { event in
                log.error("Crash has happened!", metadata: ["event": "\(event)"])
                // this is disabled because it might cause unintended redirects, since the Sentry crash detection seems to be wonky
                // DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: self.mainNavigationViewModel.displayUserFeedback)
            }

            options.beforeSend = { event in
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
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // the app was rejected by apple because a user could not open the app again after closing the main window
        true
    }
}
#else
var shortcutItemToProcess: UIApplicationShortcutItem?

enum ShortCutItemType: String, CaseIterable {
    case scan, scanAndShare

    var item: UIApplicationShortcutItem {
        switch self {
        case .scan:
            return UIApplicationShortcutItem(type: rawValue,
                                             localizedTitle: "Scan",
                                             localizedSubtitle: NSLocalizedString("Start scanning a document", comment: ""),
                                             icon: UIApplicationShortcutIcon(systemImageName: "doc.text.viewfinder"))
        case .scanAndShare:
            return UIApplicationShortcutItem(type: rawValue,
                                             localizedTitle: NSLocalizedString("Scan & Share", comment: ""),
                                             localizedSubtitle: NSLocalizedString("Start scan and share document afterwards", comment: ""),
                                             icon: UIApplicationShortcutIcon(type: .share))
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
         if let shortcutItem = options.shortcutItem {
             shortcutItemToProcess = shortcutItem
         }

         let sceneConfiguration = UISceneConfiguration(name: "Custom Configuration", sessionRole: connectingSceneSession.role)
         sceneConfiguration.delegateClass = CustomSceneDelegate.self
         return sceneConfiguration
     }
}

final class CustomSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        shortcutItemToProcess = shortcutItem
    }
}
#endif
