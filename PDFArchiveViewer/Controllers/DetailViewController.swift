/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import os.log
import PDFKit
import UIKit

class DetailViewController: UIViewController, Logging {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var documentView: PDFView!

    var detailDocument: Document? {
        didSet {
            configureView()
        }
    }

    func configureView() {
        if let detailDocument = detailDocument,
            let detailDescriptionLabel = detailDescriptionLabel,
            let documentView = documentView {

            detailDescriptionLabel.text = detailDocument.specification
            // TODO: put PDF or placeholder here
            documentView.document = PDFDocument(url: detailDocument.path)
            documentView.goToFirstPage(self)
            title = detailDocument.folder
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        documentView.displayMode = .singlePageContinuous
        documentView.autoScales = true
        documentView.interpolationQuality = .low
        documentView.backgroundColor = UIColor(named: "TextColorLight") ?? .darkGray
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
