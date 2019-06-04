//
//  DocumentViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import PDFKit.PDFDocument
import UIKit

class DocumentViewController: UIViewController, Logging {

    let document: Document
    private let pdfVC: PDFViewController
    private let dateDescriptionVC: DateDescriptionViewController
    private let tagVC: TaggingViewController

    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    init?(document: Document) {

        guard let pdfDocument = PDFDocument(url: document.path) else { fatalError("Could not find document at:\n\(document.path.path)") }

        // remove PDF Archive default decription and tags
        let description: String
        if document.description.starts(with: Constants.documentDescriptionPlaceholder) {
            description = ""
        } else {
            description = document.description
        }
        let tags = Set(document.tags.map { $0.name })

        pdfVC = PDFViewController(pdfDocument: pdfDocument)
        dateDescriptionVC = DateDescriptionViewController(date: document.date ?? Date(),
                                                          description: description)
        tagVC = TaggingViewController(documentTags: tags)

        self.document = document
        super.init(nibName: nil, bundle: nil)

        add(pdfVC)
        add(dateDescriptionVC)
        add(tagVC)

        dateDescriptionVC.delegate = self
        tagVC.delegate = self
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // basic setup
        setupViews()
        setupConstraints()

        // try to parse suggestions from document content
        DispatchQueue.global().async {
            // get tags and save them in the background, they will be passed to the TagViewController
            guard let pdfDocument = PDFDocument(url: self.document.path) else { return }
            var text = ""
            for index in 0 ..< pdfDocument.pageCount {
                guard let page = pdfDocument.page(at: index),
                    let pageContent = page.string else { return }

                text += pageContent
            }
            self.tagVC.update(suggestedTags: TagParser.parse(text))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // register keyboard notification
        registerNotifications()
        unregisterNotifications()
    }

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let stackView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.distribution = .equalSpacing
        view.alignment = .fill
        view.spacing = 15
        return view
    }()

    private func setupViews() {

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(pdfVC.view)
        stackView.addArrangedSubview(dateDescriptionVC.view)
        stackView.addArrangedSubview(tagVC.view)
    }

    private func setupConstraints() {

        scrollView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        stackView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        stackView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        stackView.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
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

// MARK: - Delegates

extension DocumentViewController: DateDescriptionViewControllerDelegate {
    func updateDateDescription(_ date: Date, _ description: String?) {
        document.date = date
        if let description = description {
            document.specification = description
        }
    }
}

extension DocumentViewController: TaggingViewControllerDelegate {
    func taggingViewController(updated tags: Set<String>) {
        for tag in document.tags where !tags.contains(tag.name) {
            DocumentService.archive.remove(tag, from: document)
        }

        let documentTags = Set(document.tags.map { $0.name })
        for tag in tags.subtracting(documentTags) {
            DocumentService.archive.add(tag: tag, to: document)
        }
    }

    func taggingViewController(didChangeText text: String) {

        // TODO: update suggestions
//        if let tagName = text,
//            !tagName.isEmpty {
//
//            let documentTags = Set(self.documentTagField.tags.map { $0.text })
//            let tags = DocumentService.archive.getAvailableTags(with: [tagName])
//                .filter { !documentTags.contains($0.name) }
//                .sorted { $0.count > $1.count }
//                .map { $0.name }
//                .prefix(3)
//            self.suggestionVC.suggestions = Array(tags)
//        } else {
//            self.suggestionVC.suggestions = []
//        }
    }
}
