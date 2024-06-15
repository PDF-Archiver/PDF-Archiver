//
//  PDFArchiverApp.swift
//  Shared
//
//  Created by Julian Kahnert on 24.06.20.
//

#if !os(macOS)
import Foundation
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
//            .environmentObject(OrientationInfo())
            .onChange(of: scenePhase) { phase in
                Self.log.info("Scene change: \(phase)")

                if phase == .active {
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
        #if !os(macOS)
        // disable transparent UITabBar on iOS 15+
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
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
#endif
