//
//  TagViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.04.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import PDFKit
import TagListView
import UIKit

class TagViewController: UIViewController, Logging {

    // these properties will be set by the DateDescriptionViewController
    var document: Document?
    var suggestedTags: Set<String>?

    private var documentViewTags = Set<String>() {
        didSet {
            // remove old tags and add the new ones
            documentTagsView.updateTags(documentViewTags)

            guard let document = document else { return }
            DocumentService.archive.update(documentViewTags, on: document)
        }
    }

    private var suggestedViewTags = Set<String>() {
        didSet {
            // remove old tags and add the new ones
            suggestedTagsView.updateTags(suggestedViewTags)
        }
    }

    @IBOutlet weak var documentTagsView: TagListView!
    @IBOutlet weak var tagSearchTextField: UITextField!
    @IBOutlet weak var suggestedTagsView: TagListView!
    @IBOutlet weak var documentTagBorderView: UIView!
    @IBOutlet weak var suggestedTagBorderView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBAction private func textFieldDidChange(_ sender: UITextField) {

        guard let tagName = sender.text,
            !tagName.isEmpty else {
                suggestedTagsView.updateTags(suggestedTags ?? [])
                return
        }

        let tags = DocumentService.archive.getAvailableTags(with: [tagName]).map { $0.name }
        guard !tags.isEmpty else { return }

        // remove old tags and add the new ones
        suggestedViewTags = Set(tags)
    }

    @IBAction private func textFieldReturn(_ sender: UITextField) {
        guard let tagName = sender.text else { return }
        documentViewTags.insert(tagName.slugified(withSeparator: "_"))
        resetSuggestedTags()
    }

    @IBAction private func backButtonTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction private func saveButtonTapped(_ sender: UIButton) {
        // TODO: use error handling here
        guard let path = Constants.archivePath else { fatalError("Could not get the iCloud Drive Archive Path.") }
        do {
            guard let document = document else { fatalError("Could not find document that should be saved. This should not happen!") }
            try document.rename(archivePath: path, slugify: true)
            DocumentService.archive.archive(document)
        } catch let error as NSError {
            os_log("Error occurred while renaming Document: %@", log: TagViewController.log, type: .error, error.localizedDescription)
        }
        self.navigationController?.popViewController(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // register keyboard notification
        registerNotifications()

        // Do any additional setup after loading the view.
        documentTagsView.delegate = self
        suggestedTagsView.delegate = self

        documentTagsView.textFont = .systemFont(ofSize: 15)
        suggestedTagsView.textFont = .systemFont(ofSize: 15)

        documentTagBorderView.layer.borderWidth = 1
        suggestedTagBorderView.layer.borderWidth = 1

        documentTagBorderView.layer.shadowRadius = 2
        suggestedTagBorderView.layer.shadowRadius = 2

        setupTags()
    }

    // MARK: - Helper Functions

    private func setupTags() {

        // get document tags
        guard let documentTags = document?.tags.map({ $0.name }) else { return }
        documentViewTags = Set(documentTags)

        // setup suggested tags
        suggestedViewTags = suggestedTags ?? []
    }

    private func resetSuggestedTags() {
        // clear up search tag field
        tagSearchTextField.text = nil
        suggestedViewTags = suggestedTags ?? []
    }

    // MARK: Keyboard Presentation

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

extension TagViewController: TagListViewDelegate {
    // MARK: TagListViewDelegate
    func tagPressed(_ title: String, tagView: TagView, sender: TagListView) {
        switchTag(title, from: sender)
    }

    func tagRemoveButtonPressed(_ title: String, tagView: TagView, sender: TagListView) {
        switchTag(title, from: sender)
    }

    private func switchTag(_ title: String, from sender: TagListView) {
        if sender == documentTagsView {
            documentViewTags.remove(title)
        } else {
            suggestedViewTags.remove(title)
            documentViewTags.insert(title)

            resetSuggestedTags()
        }
    }
}
