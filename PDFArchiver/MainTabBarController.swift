//
//  MainTabBarController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {

    override var selectedIndex: Int {
        didSet {
            saveSelectedIndex()
        }

    }

    override var selectedViewController: UIViewController? {
        didSet {
            saveSelectedIndex()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if UserDefaults.standard.tutorialShown {
            selectedIndex = UserDefaults.standard.lastSelectedTabIndex
        } else {
            selectedIndex = 2
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // we have to show the tutorial here, because the AppDelegate starts this ViewController if the app usage is not permitted
        if !UserDefaults.standard.tutorialShown {
            let introVC = IntroViewController()
            present(introVC, animated: false, completion: nil)
            UserDefaults.standard.tutorialShown = true
        }
    }

    private func saveSelectedIndex() {
        // save the selected index for the next app start
        UserDefaults.standard.lastSelectedTabIndex = selectedIndex
        Log.send(.info, "Changed tab.")
    }
}
