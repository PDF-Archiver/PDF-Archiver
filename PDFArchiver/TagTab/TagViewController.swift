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

class TagViewController: UIViewController, Logging {

    // these properties will be set by the DateDescriptionViewController
    var document: Document?
    var suggestedTags: Set<String>?

    private let documentTagField = WSTagsField()
    private let suggestedTagField = WSTagsField()
    
    // view controller that sits on top of the default keygoard
    private let suggestionVC = SuggestionInputView(nibName: nil, bundle: nil)

    @IBOutlet weak var documentTagsView: UIView!
    @IBOutlet weak var suggestedTagsView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

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

        // TODO: remove this
        let out = try? document?.getRenamingPath()
        print(out?.filename)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        TagViewController.customise(documentTagField)
        documentTagsView.addSubview(documentTagField)
        documentTagField.textDelegate = self

        TagViewController.customise(suggestedTagField)
        suggestedTagsView.addSubview(suggestedTagField)
        suggestedTagField.placeholder = ""
        suggestedTagField.textDelegate = self
//        suggestedTagField.readOnly = true

        // register keyboard notification
        registerNotifications()

        // get document tags
        if let documentTags = document?.tags.map({ $0.name }) {
            documentTagField.addTags(documentTags)
        }

        // setup suggested tags
        suggestedTagField.addTags(Array(suggestedTags ?? []))

        documentTagField.onDidSelectTagView = { _, view in

            self.documentTagField.removeTag(view.displayText)
            self.suggestedTagField.addTag(view.displayText)

            self.documentTagField.beginEditing()

            guard let document = self.document,
                let tag = document.tags.first(where: { $0.name == view.displayText }) else { return }
            DocumentService.archive.remove(tag, from: document)
        }

        documentTagField.onDidAddTag = {field, tag in
            guard let document = self.document else { return }
            DocumentService.archive.add(tag: tag.text, to: document)
        }

        documentTagField.onDidChangeText = {field, text in
            // TODO: use real tags here
            if let tagName = text,
                !tagName.isEmpty {

                let tags = DocumentService.archive.getAvailableTags(with: [tagName]).map { $0.name }
                self.suggestionVC.suggestions = Array(tags.sorted().prefix(3))
            } else {
                self.suggestionVC.suggestions = []
            }
        }

        suggestedTagField.onDidSelectTagView = {_, view in
            self.documentTagField.addTag(view.displayText)
            self.suggestedTagField.removeTag(view.displayText)
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
        field.layer.cornerRadius = 5

        field.cornerRadius = 3.0
        field.spaceBetweenLines = 10
        field.spaceBetweenTags = 10

//        field.numberOfLines = 3
//        field.maxHeight = 100.0

        field.layoutMargins = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        field.contentInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10) //old padding

        field.placeholder = "Enter a tag"
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

extension TagViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.autocorrectionType = .no
        textField.inputAccessoryView = self.suggestionVC.view
    }
}
