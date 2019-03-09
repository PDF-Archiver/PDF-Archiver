//
//  SplitViewController.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 29.12.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import UIKit

class NavigationController: UINavigationController {

    private var statusBarStyle = UIStatusBarStyle.default

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBarStyle
    }

    override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        super.setNavigationBarHidden(hidden, animated: animated)

        // setup ne status bar style
        statusBarStyle = hidden ? .lightContent : .default

        // update status bar appearance
        setNeedsStatusBarAppearanceUpdate()
    }
}
