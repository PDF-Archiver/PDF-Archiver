//
//  MoreTabViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 31.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import UIKit

struct MoreTabViewController: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> MoreTableViewController {
        // TODO: fix about page
        // TODO: navigation bar, e.g. when switching to "PDF quality"
        let storyboard = UIStoryboard(name: "MoreViewController", bundle: nil)
        guard let controller = storyboard.instantiateInitialViewController() as? MoreTableViewController else { fatalError("Could not instantiate MoreViewController.") }

        return controller
    }

    func updateUIViewController(_ uiViewController: MoreTableViewController, context: Context) {
        print("UPDATING")
    }
}
