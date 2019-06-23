//
//  MainTabBarController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let tutorialShown = UserDefaults.standard.bool(forKey: Constants.UserDefaults.tutorialShown.rawValue)
        if tutorialShown {
            selectedIndex = UserDefaults.standard.integer(forKey: Constants.UserDefaults.lastSelectedTabIndex.rawValue)
        } else {
            selectedIndex = 2
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // we have to show the tutorial here, because the AppDelegate starts this ViewController if the app usage is not permitted
        let tutorialShown = UserDefaults.standard.bool(forKey: Constants.UserDefaults.tutorialShown.rawValue)
        if !tutorialShown {
            let introVC = IntroViewController()
            present(introVC, animated: false, completion: nil)
            UserDefaults.standard.set(true, forKey: Constants.UserDefaults.tutorialShown.rawValue)
        }
    }
}
