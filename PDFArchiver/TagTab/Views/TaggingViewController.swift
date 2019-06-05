//
//  taggingViewController.swift
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

protocol TaggingViewControllerDelegate: AnyObject {
    func taggingViewController(updated tags: Set<String>)
    func taggingViewController(didChangeText text: String)
}

class TaggingViewController: UIViewController, Logging {

    weak var delegate: TaggingViewControllerDelegate?
    private var documentTags: Set<String>
    private var suggestedTags = Set<String>()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    // view controller that sits on top of the default keygoard
    private let suggestionVC = SuggestionInputViewController()

    private lazy var documentTagField: WSTagsField = {
        let field = WSTagsField()
        TaggingViewController.customise(field)

        field.onDidSelectTagView = { _, view in
            self.documentTagField.removeTag(view.displayText)
            self.documentTagField.beginEditing()
            self.selectionFeedback.prepare()
            self.selectionFeedback.selectionChanged()
        }

        field.onDidAddTag = { tagsField, tag in
            tagsField.sortTags()
            let tags = Set(tagsField.tags.map { $0.text })
            self.delegate?.taggingViewController(updated: tags)
            self.suggestedTagField.removeTag(tag.text)
        }

        field.onDidRemoveTag = { tagsField, tag in
            let tags = Set(tagsField.tags.map { $0.text })
            self.delegate?.taggingViewController(updated: tags)

            if self.suggestedTags.contains(tag.text) {
                self.suggestedTagField.addTag(tag.text)
            }
        }

        field.onDidChangeText = {_, text in
            guard let tagName = text,
                !tagName.isEmpty else { return }
            self.delegate?.taggingViewController(didChangeText: tagName)
        }
        return field
    }()

    private lazy var suggestedTagField: WSTagsField = {
        let field = WSTagsField()
        TaggingViewController.customise(field)
        field.placeholder = ""

        field.onDidSelectTagView = { tagsField, view in
            self.documentTagField.addTag(view.displayText)
            tagsField.removeTag(view.displayText)
            self.selectionFeedback.prepare()
            self.selectionFeedback.selectionChanged()
        }

        field.onDidAddTag = { tagsField, tag in
            tagsField.sortTags()
        }
        return field
    }()

    init(documentTags: Set<String>) {
        self.documentTags = documentTags
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBOutlet weak var documentTagsView: UIView!
    @IBOutlet weak var suggestedTagsView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        documentTagField.frame = documentTagsView.bounds
        documentTagsView.addSubview(documentTagField)
        documentTagField.textDelegate = self

        suggestedTagField.frame = suggestedTagsView.bounds
        suggestedTagsView.addSubview(suggestedTagField)
        suggestedTagField.textDelegate = self

        suggestionVC.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        documentTagField.frame = documentTagsView.bounds
        suggestedTagField.frame = suggestedTagsView.bounds
        suggestionVC.view.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 45)
    }

    // TODO: load tags
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//
//        documentTagField.addTags(Array(documentTags).sorted())
//        suggestedTagField.addTags(Array(suggestedTags).sorted())
//    }

    func update(suggestedTags: Set<String>) {
        self.suggestedTags.formUnion(suggestedTags)
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
        field.placeholderColor = .paPlaceholderGray
        field.textColor = .paWhite
        field.placeholderAlwaysVisible = true

        field.tintColor = .paLightRed
        field.returnKeyType = .next
        field.delimiter = ""
    }
}

// MARK: - UITextFieldDelegate

extension TaggingViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.autocorrectionType = .no
        textField.inputAccessoryView = self.suggestionVC.view
    }

//    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
//        if textField == documentTagField {
//            //            anotherField.becomeFirstResponder()
//            textField.resignFirstResponder()
//        }
//        return true
//    }
}

// MARK: - SuggestionInputViewDelegate

extension TaggingViewController: SuggestionInputViewDelegate {

    func suggestionInputViewController(_ suggestionInputView: SuggestionInputViewController, userTabbed button: UIButton) {

        guard let tagName = button.currentTitle,
            !documentTagField.contains(tagName) else { return }

        documentTagField.addTag(tagName)
        documentTagField.sortTags()
    }
}
