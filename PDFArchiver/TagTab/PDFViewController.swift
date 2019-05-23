//
//  PDFViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import PDFKit
import UIKit

class PDFViewController: UIViewController {

    @IBOutlet private var pdfView: PDFView!

    init(pdfDocument: PDFDocument) {
        self.pdfView.document = pdfDocument
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.interpolationQuality = .low
        pdfView.backgroundColor = .paLightGray
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        pdfView.goToFirstPage(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pdfView.sizeToFit()
    }
}
