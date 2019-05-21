//
//  DocumentHandleViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

class DocumentHandleViewController: UIViewController {

    @IBAction private func trashButtonTapped(_ sender: UIBarButtonItem) {
        print("TRASH")
    }

    @IBAction private func saveButtonTapped(_ sender: UIBarButtonItem) {
        print("SAVE")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // show document view controller
        let viewController = DocumentViewController()
        self.addVcAndView(viewController)

        // add layout constraints
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        let margins = view.layoutMarginsGuide
        let guide = view.safeAreaLayoutGuide
        viewController.view.leadingAnchor.constraint(equalTo: margins.leadingAnchor).isActive = true
        viewController.view.trailingAnchor.constraint(equalTo: margins.trailingAnchor).isActive = true
        viewController.view.topAnchor.constraint(equalToSystemSpacingBelow: guide.topAnchor, multiplier: 1.0).isActive = true
        guide.bottomAnchor.constraint(equalToSystemSpacingBelow: viewController.view.bottomAnchor, multiplier: 1.0).isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // TODO: add document here
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // show subscription view controller, if no subscription was found
        if !IAP.service.appUsagePermitted() {
            let viewController = SubscriptionViewController {
                self.tabBarController?.selectedIndex = self.tabBarController?.getViewControllerIndex(with: "ArchiveTab") ?? 2
            }
            present(viewController, animated: animated)
        }
    }
}
