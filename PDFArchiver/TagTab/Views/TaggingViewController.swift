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
import UIKit
import WSTagsField

protocol TaggingViewControllerDelegate: AnyObject {
    func taggingViewController(updated tags: Set<String>)
}

class TaggingViewController: UIViewController, Logging {

    weak var delegate: TaggingViewControllerDelegate?
    private var documentTags: Set<String>
    private let textChangeHandler: ((_ text: String) -> [String])
    private var suggestedTags = Set<String>()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    // view controller that sits on top of the default keygoard
    private let suggestionVC = SuggestionInputViewController()

    private lazy var documentTagField: WSTagsField = {
        let field = WSTagsField()
        field.placeholder = NSLocalizedString("tagvc.enter-tag", comment: "Placeholder in Tagging Screen.")
        field.enableScrolling = false

        field.onDidSelectTagView = { _, view in
            self.documentTagField.removeTag(view.displayText)
            self.selectionFeedback.prepare()
            self.selectionFeedback.selectionChanged()
        }

        field.onDidAddTag = { tagsField, tag in
            let tags = Set(tagsField.tags.map { $0.text.slugified(withSeparator: "").lowercased() })
            self.delegate?.taggingViewController(updated: tags)
            self.suggestedTagField.removeTag(tag.text)
        }

        field.onDidRemoveTag = { tagsField, tag in
            let tags = Set(tagsField.tags.map { $0.text })
            self.delegate?.taggingViewController(updated: tags)

            if self.suggestedTags.contains(tag.text) {
                self.suggestedTagField.addTag(tag.text)
                self.suggestedTagField.sortTags()
            }
        }

        field.onDidChangeText = {_, text in
            if let tagName = text,
                !tagName.isEmpty {
                self.suggestionVC.suggestions = self.textChangeHandler(tagName)
            } else {
                self.suggestionVC.suggestions = []
            }
        }
        return field
    }()

    private lazy var suggestedTagField: WSTagsField = {
        let field = WSTagsField()
        field.placeholder = ""
        field.enableScrolling = false

        field.onDidSelectTagView = { tagsField, view in
            self.documentTagField.addTag(view.displayText)
            self.documentTagField.sortTags()
            tagsField.removeTag(view.displayText)
            self.selectionFeedback.prepare()
            self.selectionFeedback.selectionChanged()
        }
        return field
    }()

    init(documentTags: Set<String>, onDidChange textChangeHandler: @escaping ((_ text: String) -> [String])) {
        self.documentTags = documentTags
        self.textChangeHandler = textChangeHandler
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBOutlet private weak var documentTagsView: UIView!
    @IBOutlet private weak var suggestedTagsView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        documentTagsView.addSubview(documentTagField)
        TaggingViewController.customise(documentTagField, in: documentTagsView)

        suggestedTagsView.addSubview(suggestedTagField)
        TaggingViewController.customise(suggestedTagField, in: suggestedTagsView)

        documentTagField.textDelegate = self
        suggestedTagField.textDelegate = self
        suggestionVC.delegate = self

        documentTagField.addTags(Array(documentTags).sorted())
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        suggestionVC.view.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 45)
    }

    func update(suggestedTags: Set<String>) {
        self.suggestedTags.formUnion(suggestedTags)
        self.suggestedTags.subtract(documentTags)
        DispatchQueue.main.async {
            self.suggestedTagField.addTags(Array(self.suggestedTags).sorted())
        }
    }

    func beginEditing() {
        documentTagField.beginEditing()
    }

    // MARK: - Helper Functions

    private static func customise(_ field: WSTagsField, in view: UIView) {

        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: view.topAnchor),
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            field.bottomAnchor.constraint(equalTo: view.bottomAnchor)])

        field.layer.borderWidth = 0
        field.cornerRadius = 5.0
        field.spaceBetweenLines = 10
        field.spaceBetweenTags = 10
        field.layoutMargins = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        field.contentInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10) //old padding
        field.placeholderColor = .paPlaceholderGray
        field.textColor = .white
        field.placeholderAlwaysVisible = true
        field.tintColor = .paLightRed
        field.returnKeyType = .next
        field.delimiter = ""
        field.font = .paText
        field.fieldTextColor = .paDarkGray
    }
}

// MARK: - UITextFieldDelegate

extension TaggingViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.autocorrectionType = .no
        textField.inputAccessoryView = self.suggestionVC.view
    }
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
