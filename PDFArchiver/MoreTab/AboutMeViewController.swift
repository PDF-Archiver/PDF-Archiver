//
//  AboutMeViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 09.07.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

class AboutMeViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        imageView.layer.cornerRadius = imageView.frame.width / 4
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // scroll text view to the top: https://stackoverflow.com/a/33448246
        textView.contentOffset = .zero
    }

}
