//
//  TagViewController.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 07.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import PDFKit
import UIKit

class TagViewController: UIViewController {

    @IBOutlet weak var untaggedDocumentsCount: UILabel!
    @IBOutlet weak var documentView: PDFView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var specificationTextField: UITextField!
    @IBOutlet weak var tagsTextField: UITextField!

    @IBAction private func saveButtonTapped(_ sender: UIButton) {
        print("Save button tapped.")
    }

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()

        // setup document view
        documentView.displayMode = .singlePage
        documentView.autoScales = true
        documentView.interpolationQuality = .low
        documentView.backgroundColor = .paLightGray
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateView()
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

    // MARK: - Helper Functions

    private func updateView() {
        let untaggedDocuments = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged)
        for document in untaggedDocuments {
            print(document.filename)
        }

        // untagged documents
        untaggedDocumentsCount.text = "Untagged Documents: \(untaggedDocuments.count)"

        guard let document = Array(untaggedDocuments).sorted().reversed().first else { return }

        documentView.document = PDFDocument(url: document.path)
        documentView.goToFirstPage(self)
        datePicker.date = document.date
        specificationTextField.text = document.specification
        tagsTextField.text = document.tags.reduce(into: "") { $0 += $1.name + " " }

    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
