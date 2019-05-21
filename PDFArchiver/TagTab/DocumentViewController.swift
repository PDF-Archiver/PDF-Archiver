//
//  DocumentViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import UIKit

class DocumentViewController: UIViewController {

    private let pdfVC = PDFViewController()
    private let dateDescriptionVC = DateDescriptionViewController()
    private let tagVC = TaggingViewController()

    var document: Document? {
        didSet {
            print("UPDATED DOCUMENT")
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        add(pdfVC)
        add(dateDescriptionVC)
        add(tagVC)
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
    }

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .cyan
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
}
