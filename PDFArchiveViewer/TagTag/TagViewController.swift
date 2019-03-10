//
//  TagViewController.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 07.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import UIKit

class TagViewController: UIViewController {

    @IBOutlet weak var untaggedDocumentsCount: UILabel!
    @IBOutlet weak var datePicker: UIDatePicker!

    @IBOutlet weak var specificationTextField: UITextField!
    @IBOutlet weak var tagsTextField: UITextField!

    @IBAction func saveButtonTapped(_ sender: UIButton) {
        print("Save button tapped.")
    }

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()

        updateView()
    }

    private func updateView() {
        let untaggedDocuments = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged)

        // untagged documents
        untaggedDocumentsCount.text = "Untagged Documents: \(untaggedDocuments.count)"

        for document in untaggedDocuments {
            print(document.filename)
        }

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
