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

import ArchiveLib
import os.log
import PDFKit
import TagListView
import UIKit

class DetailViewController: UIViewController, Logging {

    @IBOutlet weak var tagListView: TagListView!
    @IBOutlet weak var documentView: PDFView!
    @IBAction private func shareButtonClicked(_ sender: UIBarButtonItem) {
        guard let document = detailDocument,
            let pdfDocumentData = NSData(contentsOf: document.path) else {

            // pop up an alert dialogue letting us know it has failed
            let alertTitle = NSLocalizedString("Error", comment: "The title of an error message popup")
            let errorMessage = NSLocalizedString("Unable to share document without the pdf file", comment: "Error mesage to be displayed when failing to share a document")
            let actionTitle = NSLocalizedString("OK", comment: "Button confirmation label")

            let alert = UIAlertController(title: alertTitle,
                                          message: errorMessage,
                                          preferredStyle: .alert)
            let action = UIAlertAction(title: actionTitle,
                                       style: .default,
                                       handler: nil)
            alert.addAction(action)

            self.present(alert, animated: true, completion: nil)

            return
        }
        // creating the sharing activity view controller
        let activity = UIActivityViewController(activityItems: [pdfDocumentData],
                                                applicationActivities: nil)
        // presenting it
        self.present(activity, animated: true, completion: nil)
    }

    var detailDocument: Document? {
        didSet {
            configureView()
        }
    }

    func configureView() {
        if let detailDocument = detailDocument,
            let tagListView = tagListView,
            let documentView = documentView {

            // set the title
            title = detailDocument.specificationCapitalized

            // set the subtitle
            tagListView.removeAllTags()
            tagListView.addTags(detailDocument.tags.map { String($0.name) })

            // setup the pdf view
            documentView.document = PDFDocument(url: detailDocument.path)
            documentView.goToFirstPage(self)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // setup document view
        documentView.displayMode = .singlePageContinuous
        documentView.autoScales = true
        documentView.interpolationQuality = .low
        documentView.backgroundColor = UIColor(named: "TextColorLight") ?? .darkGray

        // setup tag list view
        tagListView.tagBackgroundColor = UIColor(named: "TagBackground") ?? .darkGray
        tagListView.textFont = UIFont.systemFont(ofSize: 16)
        tagListView.alignment = .center
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
