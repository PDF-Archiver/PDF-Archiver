//
//  PlaceholderViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 04.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

class PlaceholderViewController: UIViewController {

    private let imageView = UIImageView()
    private let label = UILabel()

    init(text: String) {
        label.text = text
        label.font = .paText
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = #imageLiteral(resourceName: "Logo")
        label.textAlignment = .center
        label.numberOfLines = 5

        setupConstraints()
    }

    private func setupConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(imageView)
        view.addSubview(label)

        imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.33).isActive = true

        label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10).isActive = true
        label.centerXAnchor.constraint(equalTo: imageView.centerXAnchor).isActive = true
        label.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.66).isActive = true
    }
}
