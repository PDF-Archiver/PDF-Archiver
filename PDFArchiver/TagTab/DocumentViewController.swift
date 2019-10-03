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

class DocumentViewController: UIViewController, SystemLogging {

    let document: Document
    private let pdfVC: PDFViewController
    private let dateDescriptionVC: DateDescriptionViewController
    private lazy var taggingVC: TaggingViewController = {
        let textChangeHandler: ((_ text: String) -> [String]) = { [weak self] (_ tagName: String) in
            let tags = DocumentService.archive.getAvailableTags(with: [tagName])
                .subtracting(self?.document.tags ?? [])
                .filter { $0 != Constants.documentTagPlaceholder }
                .map { $0 }
                .prefix(3)
            return Array(tags)
        }
        return TaggingViewController(documentTags: document.tags, onDidChange: textChangeHandler)
    }()

    init?(document: Document) {

        guard let pdfDocument = PDFDocument(url: document.path) else {
            assertionFailure("Could not find document at:\n\(document.path.path)")
            return nil
        }

        // remove PDF Archive default decription and tags
        let description: String
        if document.specification.lowercased().starts(with: Constants.documentDescriptionPlaceholder.lowercased()) {
            description = ""
        } else {
            description = document.specification
        }

        pdfVC = PDFViewController(pdfDocument: pdfDocument)

        // update document date, if it is currently nil or is not the PDF Archiver naming schema, e.g. "2019-09-21--..."
        let shouldUpdateDate = document.date == nil || !(document.filename.contains("--") && document.filename.contains("__"))
        let displayDate = document.date ?? Date()
        dateDescriptionVC = DateDescriptionViewController(date: displayDate,
                                                          description: description)
        self.document = document
        super.init(nibName: nil, bundle: nil)

        parseContentIfNeeded(of: pdfDocument, updateDate: shouldUpdateDate)

        add(pdfVC)
        add(dateDescriptionVC)
        add(taggingVC)

        scrollView.delegate = self
        dateDescriptionVC.delegate = self
        taggingVC.delegate = self
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // basic setup
        stackView.spacing = 0.0
        setupViews()
        setupConstraints()
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

    private func parseContentIfNeeded(of pdfDocument: PDFDocument, updateDate: Bool) {

        // ATTENTION: this will be used in the init on the main thread - use dispatch queues here!

        // use the current date, if no date was set
        if updateDate {

            // try to get the date from document content
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                // get tags and save them in the background, they will be passed to the TagViewController
                guard let text = pdfDocument.string,
                    let date = DateParser.parse(text)?.date else { return }

                DispatchQueue.main.async {
                    self?.dateDescriptionVC.update(date: date)
                    self?.document.date = date
                }
            }
        }

        // try to parse suggestions from document content
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // get tags and save them in the background, they will be passed to the TagViewController
            guard let text = pdfDocument.string else { return }
            self?.taggingVC.update(suggestedTags: TagParser.parse(text))
        }
    }

    private func createHairLine(in view: UIStackView) {
        let hline = UIView(frame: .zero)
        view.addArrangedSubview(hline)
        hline.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        hline.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        hline.heightAnchor.constraint(equalToConstant: HairlineConstraint.height).isActive = true
        hline.backgroundColor = .paPlaceholderGray
    }

    private func setupViews() {

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(pdfVC.view)
        stackView.addArrangedSubview(dateDescriptionVC.view)
        createHairLine(in: stackView)
        stackView.addArrangedSubview(taggingVC.view)
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
            let spacing = CGFloat(15)
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

    func dateDescriptionView(_ sender: DateDescriptionViewController, didChangeDate date: Date) {
        document.date = date
    }

    func dateDescriptionView(_ sender: DateDescriptionViewController, didChangeDescription description: String) {
        document.specification = description
    }

    func dateDescriptionView(_ sender: DateDescriptionViewController, shouldReturnFrom textField: UITextField) {
        textField.resignFirstResponder()
        taggingVC.beginEditing()
    }
}

extension DocumentViewController: TaggingViewControllerDelegate {
    func taggingViewController(updated tags: Set<String>) {
        document.tags = tags
    }
}
