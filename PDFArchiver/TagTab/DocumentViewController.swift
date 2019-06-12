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

        scrollView.delegate = self
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
        DispatchQueue.global().async { [weak self] in
            // get tags and save them in the background, they will be passed to the TagViewController
            guard let path = self?.document.path,
                let pdfDocument = PDFDocument(url: path) else { return }
            var text = ""
            for index in 0 ..< pdfDocument.pageCount {
                guard let page = pdfDocument.page(at: index),
                    let pageContent = page.string else { return }

                text += pageContent
            }
            self?.tagVC.update(suggestedTags: TagParser.parse(text))
        }

        hideKeyboardWhenTappedAround()
        scrollView.keyboardDismissMode = .interactive
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
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
        view.spacing = 5
        return view
    }()

    private func createHairLine(in view: UIView) -> UIView {
        let hline = UIView(frame: .zero)
        hline.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
        hline.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
        hline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        hline.backgroundColor = .paLightGray
        return hline
    }
    
    private func setupViews() {

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(pdfVC.view)
        stackView.addArrangedSubview(createHairLine(in: stackView))
        stackView.addArrangedSubview(dateDescriptionVC.view)
        stackView.addArrangedSubview(createHairLine(in: stackView))
        stackView.addArrangedSubview(tagVC.view)
    }

    private func setupConstraints() {

        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        stackView.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
    }

    @objc
    private func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)

        let contentInset: UIEdgeInsets
        if notification.name == UIResponder.keyboardWillHideNotification {
            contentInset = .zero
        } else {
            let spacing = CGFloat(5)
            let bottomInset = tabBarController?.tabBar.frame.height
            contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - (bottomInset ?? 0) + spacing, right: 0)
        }
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset
    }
}

// MARK: - Delegates

extension DocumentViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // fixes this problem: https://stackoverflow.com/a/34101920
        scrollView.endEditing(true)
    }
}

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
