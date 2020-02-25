//
//  SceneDelegate.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    let viewModel = MainTabViewModel()

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for urlContext in URLContexts {
            handle(url: urlContext.url)
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        // Use a UIHostingController as window root view controller
        if let windowScene = scene as? UIWindowScene {

            let view = MainTabView(viewModel: viewModel)
                .accentColor(Color(.paDarkGray))
                .environmentObject(OrientationInfo())  
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: view)

            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // send logs in background
        let application = UIApplication.shared
        Log.sendOrPersistInBackground(application)
    }

    private func handle(url: URL) {
        Log.send(.info, "Handling shared document", extra: ["filetype": url.pathExtension])

        // show scan tab with document processing, after importing a document
        viewModel.currentTab = 0

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

                AlertViewModel.createAndPost(message: error, primaryButtonTitle: "OK")
            }
        }
    }
}
