//
//  DateDescriptionViewController
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 07.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import PDFKit
import UIKit

class DateDescriptionViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var untaggedDocumentsCount: UILabel!
    @IBOutlet weak var documentView: PDFView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var specificationTextField: UITextField!
    @IBOutlet weak var nextButton: UIButton!

    @IBAction private func nextButtonTapped(_ sender: UIButton) {
        print("Next button tapped.")
    }

    var document: Document?

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

        // register keyboard notification
        registerNotifications()

        // get documents from archive
        let untaggedDocuments = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged)
        document = Array(untaggedDocuments).sorted().first

        // update untagged documents label
        untaggedDocumentsCount.text = "Untagged Documents: \(untaggedDocuments.count)"

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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destinationVC = segue.destination as? TagViewController else { return }
        destinationVC.document = document
    }

    // MARK: - Helper Functions

    private func updateView() {

        guard let document = self.document else { return }

        documentView.document = PDFDocument(url: document.path)
        documentView.goToFirstPage(self)
        datePicker.date = document.date
        specificationTextField.text = document.specification
//        tagsTextField.text = document.tags.reduce(into: "") { $0 += $1.name + " " }

    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    private func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func unregisterNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        scrollView.contentInset.bottom = view.convert(keyboardFrame.cgRectValue, from: nil).size.height
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
    }

}
