//
//  DetailViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.12.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import PDFKit
import UIKit

class DetailViewController: UIViewController, Logging {

    private var viewControllerShown: Date?

    // TODO: might only need prefersStatusBarHidden?!
    private var isNavigationBarHidden = false {
        didSet {
            DispatchQueue.main.async {
                self.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }

    override var prefersStatusBarHidden: Bool {
        return isNavigationBarHidden
    }

    var detailDocument: Document? {
        didSet {
            configureView()
        }
    }

    // MARK: - outlets
    @IBOutlet weak var documentView: PDFView!

    @IBAction private func cancelButtonClicked(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction private func shareButtonClicked(_ sender: UIBarButtonItem) {
        guard let document = detailDocument else {

            // pop up an alert dialogue letting us know it has failed
            let alertTitle = NSLocalizedString("Error", comment: "The title of an error message popup")
            let errorMessage = NSLocalizedString("Unable to share document without the pdf file", comment: "Error mesage to be displayed when failing to share a document")
            let actionTitle = NSLocalizedString("OK", comment: "Button confirmation label")

            let alert = UIAlertController(title: alertTitle,
                                          message: errorMessage,
                                          preferredStyle: .alert)
            let action = UIAlertAction(title: actionTitle,
                                       style: .default,
                                       handler: nil)
            alert.addAction(action)

            present(alert, animated: true, completion: nil)

            return
        }
        // creating the sharing activity view controller
        let activity = UIActivityViewController(activityItems: [document.path],
                                                applicationActivities: nil)

        // set a location in the popoverPresentationController that will be used on iPads
        activity.popoverPresentationController?.barButtonItem = sender

        // presenting it
        present(activity, animated: true, completion: nil)
    }

    @IBAction private func tapGestureRecognizer(_ sender: UITapGestureRecognizer) {

        // change the state of the navigation bar
        isNavigationBarHidden.toggle()

        // animate the navigation bar
        // TODO: fix the color change
        navigationController?.setNavigationBarHidden(isNavigationBarHidden, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // setup document view
        documentView.displayMode = .singlePageContinuous
        documentView.autoScales = true
        documentView.interpolationQuality = .low
        documentView.backgroundColor = .paLightGray

        configureView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        documentView.goToFirstPage(self)

        // show the whole document in the view
        documentView.maxScaleFactor = 4.0
        documentView.minScaleFactor = documentView.scaleFactorForSizeToFit
        documentView.scaleFactor = documentView.scaleFactorForSizeToFit

        viewControllerShown = Date()
    }

    override func viewWillDisappear(_ animated: Bool) {

        // cascade viewDidDisappear(:)
        super.viewWillDisappear(animated)

        // change status bar text color
        // TODO: fix the color change
        navigationController?.setNavigationBarHidden(false, animated: true)

        if let viewControllerShown = viewControllerShown {
            let timeDiff = Date().timeIntervalSinceReferenceDate - viewControllerShown.timeIntervalSinceReferenceDate
            Log.info("ArchiveTab: Presenting a document.", extra: ["presented_time": timeDiff])
        }
    }

    // MARK: - helper functions
    private func configureView() {
        if let detailDocument = detailDocument,
            let documentView = documentView {

            // set the title
            title = detailDocument.specificationCapitalized

            // setup the pdf view
            documentView.document = PDFDocument(url: detailDocument.path)
            documentView.goToFirstPage(self)
        }
    }
}
