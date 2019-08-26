//
//  DocumentHandleViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import UIKit

class DocumentHandleViewController: UIViewController, Logging {

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let placeholderViewController = PlaceholderViewController(text: NSLocalizedString("tag_tab.background_placeholder", comment: "Placeholder that is shown, when no untagged documents can be found."))
    private var documentViewController: DocumentViewController?

    @IBOutlet weak var trashButton: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIBarButtonItem!

    @IBAction private func trashButtonTapped(_ sender: UIBarButtonItem) {

        Log.info("Trash a document.")

        let deleteActionHandler: (UIAlertAction) -> Void = {(_) in
            guard let document = self.documentViewController?.document else { return }
            self.notificationFeedback.prepare()

            do {
                os_log("Deleting file: %@", log: DocumentHandleViewController.log, type: .debug, document.path.path)
                // trash file - the archive will be informed by the filesystem aka. DocumentsQuery
                try FileManager.default.removeItem(at: document.path)
                DocumentService.archive.remove(Set([document]))

                self.documentViewController?.remove()
                self.documentViewController?.dismiss(animated: true, completion: nil)
                self.documentViewController = nil

                self.notificationFeedback.notificationOccurred(.success)
                self.updateContent()

            } catch {
                os_log("Failed to delete: %@", log: DocumentHandleViewController.log, type: .error, error.localizedDescription)
                self.notificationFeedback.notificationOccurred(.error)
            }
        }

        let alert = UIAlertController(title: NSLocalizedString("Do you really want to delete this document?", comment: "Camera access in ScanViewController."),
                                      message: nil,
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete document."), style: .destructive, handler: deleteActionHandler))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel deletion."), style: .cancel, handler: nil))

        // set a location in the popoverPresentationController that will be used on iPads
        alert.popoverPresentationController?.barButtonItem = sender
        present(alert, animated: true, completion: nil)
    }

    @IBAction private func saveButtonTapped(_ sender: UIBarButtonItem) {

        Log.info("Save a document in archive.")

        guard let document = documentViewController?.document else { return }
        guard let path = StorageHelper.Paths.archivePath else {
            assertionFailure("Could not find a iCloud Drive url.")
            present(StorageHelper.Paths.iCloudDriveAlertController, animated: true, completion: nil)
            return
        }

        notificationFeedback.prepare()
        do {
            try document.rename(archivePath: path, slugify: true)
            DocumentService.archive.archive(document)

            // set current document to nil, to get a new document in updateView()
            documentViewController?.remove()
            documentViewController?.dismiss(animated: true, completion: nil)
            documentViewController = nil

            // send haptic feedback
            notificationFeedback.notificationOccurred(.success)

            // update the view to get a new document
            updateContent()

            // increment the AppStoreReview counter
            AppStoreReviewRequest.shared.incrementCount()

        } catch let error as LocalizedError {
            os_log("Error occurred while renaming Document: %@", log: DocumentHandleViewController.log, type: .error, error.localizedDescription)

            // OK button will be created by the convenience initializer
            let alertController = UIAlertController(error, preferredStyle: .alert)
            present(alertController, animated: true, completion: nil)
            notificationFeedback.notificationOccurred(.error)
        } catch {
            os_log("Error occurred while renaming Document: %@", log: DocumentHandleViewController.log, type: .error, error.localizedDescription)
            let alertController = UIAlertController(title: NSLocalizedString("error_message_fallback", comment: "Fallback when no localized error was found."), message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Button confirmation label"), style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
            notificationFeedback.notificationOccurred(.error)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("document_handle_view_controller.title", comment: "Title of the document handle view controller.")
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.barTintColor = .paWhite
        addVcAndView(placeholderViewController)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateContent()

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

    override func viewDidLayoutSubviews() {
        placeholderViewController.view.bounds = view.bounds
    }

    // MARK: - Helper Function

    private func updateContent() {

        // test if the document is already available, update view with the recently added document otherwise
        guard documentViewController == nil else { return }

        let documents = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged).filter { $0.downloadStatus == .local }

        if let document = Array(documents).max(),
            let viewController = DocumentViewController(document: document.cleaned()) {

            // show document view controller
            addVcAndView(viewController)
            documentViewController = viewController
            setupConstraints()

            selectionFeedback.prepare()
            selectionFeedback.selectionChanged()
        } else {
            documentViewController?.dismiss(animated: true, completion: nil)
            documentViewController = nil
        }

        placeholderViewController.view.isHidden = documentViewController != nil
        trashButton.isEnabled = documentViewController != nil
        saveButton.isEnabled = documentViewController != nil
    }

    private func setupConstraints() {
        guard let viewController = documentViewController else { return }

        viewController.view.translatesAutoresizingMaskIntoConstraints = false

        viewController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        viewController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        viewController.view.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        viewController.view.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
    }
}

extension DocumentHandleViewController: ArchiveDelegate {

    func archive(_ archive: Archive, didAddDocument document: Document) {
        if document.taggingStatus != .untagged {
            return
        }

        DispatchQueue.main.async {
            self.updateContent()
        }
    }

    func archive(_ archive: Archive, didRemoveDocuments documents: Set<Document>) {

        let untaggedDocuments = documents.filter { $0.taggingStatus == .untagged }
        if untaggedDocuments.isEmpty {
            return
        }

        DispatchQueue.main.async {
            self.updateContent()
        }
    }
}
