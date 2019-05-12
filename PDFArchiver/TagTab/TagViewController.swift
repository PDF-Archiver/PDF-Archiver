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
import WSTagsField

protocol TagViewControllerDelegate: AnyObject {
    func tagViewController(_ tagViewController: TagViewController, didSaveFor document: Document)
}

class TagViewController: UIViewController, Logging {

    // these properties will be set by the DateDescriptionViewController
    var document: Document?
    var suggestedTags: Set<String>?
    weak var delegate: TagViewControllerDelegate?

    private let documentTagField = WSTagsField()
    private let suggestedTagField = WSTagsField()

    // view controller that sits on top of the default keygoard
    private let suggestionVC = SuggestionInputView(nibName: nil, bundle: nil)

    @IBOutlet weak var documentTagsView: UIView!
    @IBOutlet weak var suggestedTagsView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBAction private func backButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction private func saveButtonTapped(_ sender: Any) {

        // dismiss the current VC
        if let document = document {
            delegate?.tagViewController(self, didSaveFor: document)
        }
        dismiss(animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        TagViewController.customise(documentTagField)
        documentTagsView.addSubview(documentTagField)
        documentTagField.textDelegate = self
        suggestionVC.delegate = self

        TagViewController.customise(suggestedTagField)
        suggestedTagsView.addSubview(suggestedTagField)
        suggestedTagField.placeholder = ""
        suggestedTagField.textDelegate = self

        // register keyboard notification
        registerNotifications()

        // get document tags
        let documentTags = document?.tags.map { $0.name } ?? []
        documentTagField.addTags(documentTags.sorted())

        // setup suggested tags
        let displayedSuggestedTags = (suggestedTags ?? []).subtracting(documentTags)
        suggestedTagField.addTags(Array(displayedSuggestedTags).sorted())

        documentTagField.onDidSelectTagView = { _, view in
            self.documentTagField.removeTag(view.displayText)
            self.documentTagField.beginEditing()
            guard let document = self.document,
                let tag = document.tags.first(where: { $0.name == view.displayText }) else { return }
            DocumentService.archive.remove(tag, from: document)
        }

        documentTagField.onDidAddTag = {_, tag in
            guard let document = self.document else { return }
            DocumentService.archive.add(tag: tag.text, to: document)
            self.suggestedTagField.removeTag(tag.text)
        }

        documentTagField.onDidRemoveTag = {_, tag in
            if self.suggestedTags?.contains(tag.text) ?? false {
                self.suggestedTagField.addTag(tag.text)
                self.suggestedTagField.sortTags()
            }
        }

        documentTagField.onDidChangeText = {_, text in
            if let tagName = text,
                !tagName.isEmpty {

                let documentTags = Set(self.documentTagField.tags.map { $0.text })
                let tags = DocumentService.archive.getAvailableTags(with: [tagName])
                    .filter { !documentTags.contains($0.name) }
                    .sorted { $0.count > $1.count }
                    .map { $0.name }
                    .prefix(3)
                self.suggestionVC.suggestions = Array(tags)
            } else {
                self.suggestionVC.suggestions = []
            }
        }

        suggestedTagField.onDidSelectTagView = {_, view in
            self.documentTagField.addTag(view.displayText)
            self.documentTagField.sortTags()
        }

        suggestedTagField.onDidAddTag = {_, tag in
            self.documentTagField.removeTag(tag.text)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        documentTagField.beginEditing()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        documentTagField.frame = documentTagsView.bounds
        suggestedTagField.frame = suggestedTagsView.bounds

        suggestionVC.view.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50)
    }

    // MARK: - Helper Functions

    private static func customise(_ field: WSTagsField) {

        field.translatesAutoresizingMaskIntoConstraints = false

        field.layer.borderColor = UIColor.paLightGray.cgColor
        field.layer.borderWidth = 1
        field.layer.cornerRadius = 10

        field.cornerRadius = 5.0
        field.spaceBetweenLines = 10
        field.spaceBetweenTags = 10

//        field.numberOfLines = 3
//        field.maxHeight = 100.0

        field.layoutMargins = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        field.contentInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10) //old padding

        field.placeholder = NSLocalizedString("tagvc.enter-tag", comment: "Placeholder in Tagging Screen.")
        field.placeholderColor = .paDarkGray
        field.textColor = .paWhite
        field.placeholderAlwaysVisible = true

        field.tintColor = .paLightRed
        field.returnKeyType = .next
        field.delimiter = ""
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

// MARK: - UITextFieldDelegate

extension TagViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.autocorrectionType = .no
        textField.inputAccessoryView = self.suggestionVC.view
    }
}

// MARK: - SuggestionInputViewDelegate

extension TagViewController: SuggestionInputViewDelegate {

    func suggestionInputView(_ suggestionInputView: SuggestionInputView, userTabbed button: UIButton) {

        guard let tagName = button.currentTitle,
            !documentTagField.contains(tagName) else { return }

        documentTagField.addTag(tagName)
        documentTagField.sortTags()
    }
}
