//
//  DateDescriptionViewController
//  PDFArchiver
//
//  Created by Julian Kahnert on 07.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import PDFKit
import UIKit

class DateDescriptionViewController2: UIViewController, Logging {

    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    private var suggestedTags = Set<String>()
    var document: Document? {
        didSet {

            if let document = document {
                // remove PDF Archive default decription and tags
                if document.specification.starts(with: Constants.documentDescriptionPlaceholder) {
                    document.specification = ""
                }
                if let placeholderTag = document.tags.first(where: { $0.name == Constants.documentTagPlaceholder }) {
                    document.tags.remove(placeholderTag)
                } else {
                    suggestedTags = Set(document.tags.map { $0.name })
                }
            }

            DispatchQueue.global().async {
                // get tags and save them in the background, they will be passed to the TagViewController
                guard let path = self.document?.path,
                    let pdfDocument = PDFDocument(url: path) else { return }
                var text = ""
                for index in 0 ..< pdfDocument.pageCount {
                    guard let page = pdfDocument.page(at: index),
                        let pageContent = page.string else { return }

                    text += pageContent
                }
                self.suggestedTags.formUnion(TagParser.parse(text))
            }
        }
    }

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var untaggedDocumentsCount: UILabel!
    @IBOutlet weak var documentView: PDFView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var deleteNavButton: UIBarButtonItem!
    @IBOutlet weak var editNavButton: UIBarButtonItem!

    @IBAction private func deleteNavButtonTapped(_ sender: Any) {

        let deleteActionHandler: (UIAlertAction) -> Void = {(_) in
            guard let document = self.document else { return }
            self.notificationFeedback.prepare()
            do {
                os_log("Deleting file: %@", log: DateDescriptionViewController2.log, type: .debug, document.path.path)
                // trash file - the archive will be informed by the filesystem aka. DocumentsQuery
                try FileManager.default.removeItem(at: document.path)
                DocumentService.archive.remove(Set([document]))
                self.document = nil

                // send haptic feedback
                self.notificationFeedback.notificationOccurred(.success)

                self.updateView()

            } catch {
                os_log("Failed to delete: %@", log: DateDescriptionViewController2.log, type: .error, error.localizedDescription)
                self.notificationFeedback.notificationOccurred(.error)
            }
        }

        let alert = UIAlertController(title: NSLocalizedString("Do you really want to delete this document?", comment: "Camera access in ScanViewController."),
                                      message: nil,
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete document."), style: .destructive, handler: deleteActionHandler))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel deletion."), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @IBAction private func editNavButtonTapped(_ sender: Any) {
        guard let modelVC = self.storyboard?.instantiateViewController(withIdentifier: "tags") as? TagViewController else { return }
        modelVC.document = document
        modelVC.suggestedTags = suggestedTags
        modelVC.delegate = self
        let navBarOnModal = UINavigationController(rootViewController: modelVC)
        self.present(navBarOnModal, animated: true, completion: nil)
    }

    @IBAction private func datePicker(_ sender: UIDatePicker) {
        document?.date = datePicker.date
    }

    @IBAction private func descriptionTextField(_ sender: UITextField) {
        guard let text = descriptionTextField.text else { return }
        document?.specification = text
    }

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()

        // setup document view
        documentView.displayMode = .singlePageContinuous
        documentView.autoScales = true
        documentView.interpolationQuality = .low
        documentView.backgroundColor = .paLightGray

        documentView.goToFirstPage(self)

//        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 5000, height: 5000))
//        contentView.backgroundColor = .green
//
//        let scrollView = UIScrollView()
//        scrollView.contentSize = contentView.frame.size
//        scrollView.addSubview(contentView)
//        scrollView.flashScrollIndicators()
//        scrollView.backgroundColor = .white
//
//        self.view = scrollView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // setup data delegate
        DocumentService.archive.delegate = self

        // register keyboard notification
        registerNotifications()

        // update view with the current document state
        updateView()
    }

//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//
//        // show subscription view controller, if no subscription was found
//        if !IAP.service.appUsagePermitted() {
//            let viewController = SubscriptionViewController {
//                self.tabBarController?.selectedIndex = self.tabBarController?.getViewControllerIndex(with: "ArchiveTab") ?? 2
//            }
//            present(viewController, animated: animated)
//        }
//    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        documentView.sizeToFit()
    }

    // MARK: - Helper Functions

    private func updateView() {

        if document == nil {

            // set a new document, if it does not exist already - placeholder description/tags will be removed by didSet of the document
            let untaggedDocuments = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged).filter { $0.downloadStatus == .local }
            document = Array(untaggedDocuments).max()

            if document != nil {
                // send haptic feedback
                selectionFeedback.prepare()
                selectionFeedback.selectionChanged()
            }
        }

        // update untagged documents label
        updateDocumentsCount()

        if let document = self.document,
            FileManager.default.fileExists(atPath: document.path.path),
            document.downloadStatus == .local {

            deleteNavButton.isEnabled = true
            editNavButton.isEnabled = true
            documentView.document = PDFDocument(url: document.path)
            documentView.goToFirstPage(self)
            datePicker.date = document.date ?? Date()
            descriptionTextField.text = document.specification

        } else {
            deleteNavButton.isEnabled = false
            editNavButton.isEnabled = false
            documentView.document = nil
            datePicker.date = Date()
            descriptionTextField.text = nil
        }
    }

    private func updateDocumentsCount() {
        // get documents from archive
        let untaggedDocuments = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged).filter { $0.downloadStatus == .local }

        // update untagged documents label
        let prefix = NSLocalizedString("tagging.date-description.untagged-documents", comment: "")
        untaggedDocumentsCount.text = prefix + ": \(untaggedDocuments.count)"
    }

    // MARK: - Keyboard Presentation

    private func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func unregisterNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc
    func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        scrollView.contentInset.bottom = view.convert(keyboardFrame.cgRectValue, from: nil).size.height
    }

    @objc
    func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
    }
}

extension DateDescriptionViewController2: ArchiveDelegate {

    func archive(_ archive: Archive, didAddDocument document: Document) {
        if document.taggingStatus != .untagged {
            return
        }

        DispatchQueue.main.async {

            // test if the document is already available, update view with the recently added document otherwise
            if self.document == nil {
                self.updateView()
            } else {
                self.updateDocumentsCount()
            }
        }
    }

    func archive(_ archive: Archive, didRemoveDocuments documents: Set<Document>) {

        let untaggedDocuments = documents.filter { $0.taggingStatus == .untagged }
        if untaggedDocuments.isEmpty {
            return
        }

        DispatchQueue.main.async {
            if let document = self.document, untaggedDocuments.contains(document) {
                self.updateView()
            } else {
                self.updateDocumentsCount()
            }
        }
    }
}

extension DateDescriptionViewController2: TagViewControllerDelegate {
    func tagViewController(_ tagViewController: TagViewController, didSaveFor document: Document) {

        notificationFeedback.prepare()

        // save document in archive
        guard let path = StorageHelper.Paths.archivePath else {
            assertionFailure("Could not find a iCloud Drive url.")
            self.present(StorageHelper.Paths.iCloudDriveAlertController, animated: true, completion: nil)
            return
        }
        do {
            try document.rename(archivePath: path, slugify: true)
            DocumentService.archive.archive(document)

            // set current document to nil, to get a new document in updateView()
            self.document = nil

            // send haptic feedback
            notificationFeedback.notificationOccurred(.success)

        } catch {
            os_log("Error occurred while renaming Document: %@", log: TagViewController.log, type: .error, error.localizedDescription)
            notificationFeedback.notificationOccurred(.error)
        }

        // update the view to get a new document
        updateView()

        // increment the AppStoreReview counter
        AppStoreReviewRequest.shared.incrementCount()
    }
}
