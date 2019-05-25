//
//  DocumentHandleViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import UIKit

class DocumentHandleViewController: UIViewController {

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private var documentViewController: DocumentViewController?
    @IBOutlet weak var trashButton: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIBarButtonItem!

    @IBAction private func trashButtonTapped(_ sender: UIBarButtonItem) {
        print("TRASH")

//        let deleteActionHandler: (UIAlertAction) -> Void = {(_) in
//            guard let document = self.document else { return }
//            self.notificationFeedback.prepare()
//            do {
//                os_log("Deleting file: %@", log: DateDescriptionViewController2.log, type: .debug, document.path.path)
//                // trash file - the archive will be informed by the filesystem aka. DocumentsQuery
//                try FileManager.default.removeItem(at: document.path)
//                DocumentService.archive.remove(Set([document]))
//                self.document = nil
//
//                // send haptic feedback
//                self.notificationFeedback.notificationOccurred(.success)
//
//                self.updateView()
//
//            } catch {
//                os_log("Failed to delete: %@", log: DateDescriptionViewController2.log, type: .error, error.localizedDescription)
//                self.notificationFeedback.notificationOccurred(.error)
//            }
//        }
//
//        let alert = UIAlertController(title: NSLocalizedString("Do you really want to delete this document?", comment: "Camera access in ScanViewController."),
//                                      message: nil,
//                                      preferredStyle: .actionSheet)
//        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete document."), style: .destructive, handler: deleteActionHandler))
//        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel deletion."), style: .cancel, handler: nil))
//        present(alert, animated: true, completion: nil)
    }

    @IBAction private func saveButtonTapped(_ sender: UIBarButtonItem) {
        print("SAVE")

//        guard let document = document else { return }
//        guard let path = StorageHelper.Paths.archivePath else {
//            assertionFailure("Could not find a iCloud Drive url.")
//            self.present(StorageHelper.Paths.iCloudDriveAlertController, animated: true, completion: nil)
//            return
//        }
//
//        notificationFeedback.prepare()
//        do {
//            try document.rename(archivePath: path, slugify: true)
//            DocumentService.archive.archive(document)
//
//            // set current document to nil, to get a new document in updateView()
//            self.document = nil
//
//            // send haptic feedback
//            notificationFeedback.notificationOccurred(.success)
//
//        } catch {
//            os_log("Error occurred while renaming Document: %@", log: TagggingViewController.log, type: .error, error.localizedDescription)
//            notificationFeedback.notificationOccurred(.error)
//        }
//
//        // update the view to get a new document
//        updateView()
//
//        // increment the AppStoreReview counter
//        AppStoreReviewRequest.shared.incrementCount()
    }

    override func viewDidLoad() {
        super.viewDidLoad()


    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let documents = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged).filter { $0.downloadStatus == .local }

        if let document = Array(documents).max(),
            let viewController = DocumentViewController(document: document) {

            // show document view controller
            addVcAndView(viewController)
            documentViewController = viewController
            setupConstraints()

            selectionFeedback.prepare()
            selectionFeedback.selectionChanged()
        } else {
            documentViewController = nil
        }

        trashButton.isEnabled = documentViewController != nil
        saveButton.isEnabled = documentViewController != nil

        // setup data delegate
        DocumentService.archive.delegate = self
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

    // MARK: - Helper Function

    private func setupConstraints() {
        guard let viewController = documentViewController else { return }

        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        let margins = view.layoutMarginsGuide
        let guide = view.safeAreaLayoutGuide
        viewController.view.leadingAnchor.constraint(equalTo: margins.leadingAnchor).isActive = true
        viewController.view.trailingAnchor.constraint(equalTo: margins.trailingAnchor).isActive = true
        viewController.view.topAnchor.constraint(equalToSystemSpacingBelow: guide.topAnchor, multiplier: 1.0).isActive = true
        guide.bottomAnchor.constraint(equalToSystemSpacingBelow: viewController.view.bottomAnchor, multiplier: 1.0).isActive = true
    }
}

extension DocumentHandleViewController: ArchiveDelegate {

    func archive(_ archive: Archive, didAddDocument document: Document) {
        if document.taggingStatus != .untagged {
            return
        }

        DispatchQueue.main.async {

            // test if the document is already available, update view with the recently added document otherwise
            if self.documentViewController == nil {
                print("UPDATE VIEW")
//                self.updateView()
            }
        }
    }

    func archive(_ archive: Archive, didRemoveDocuments documents: Set<Document>) {

        let untaggedDocuments = documents.filter { $0.taggingStatus == .untagged }
        if untaggedDocuments.isEmpty {
            return
        }

        DispatchQueue.main.async {
            if self.documentViewController == nil {
                print("UPDATE VIEW: archive()")
//                self.updateView()
            }
        }
    }
}
