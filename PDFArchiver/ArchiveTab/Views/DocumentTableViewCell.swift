//
//  DocumentTableViewCell.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 12.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import UIKit

class DocumentTableViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var tagListView: UISearchTextField!
    @IBOutlet weak var downloadStatusView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var sizeLabel: UILabel!

    var document: Document? {
        didSet {
            if let document = document {

                guard let date = document.date else { fatalError("Document has no date.") }

                // update title + date
                titleLabel.text = document.specificationCapitalized
                dateLabel.text = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
                sizeLabel.text = document.size

                // update the document tags
                let image = UIImage(systemName: "tag")
                tagListView.tokens = Array(document.tags)
                    .sorted { $0.name < $1.name }
                    .map { UISearchToken(icon: image, text: $0.name) }

                // update download status
                updateDownloadStatus(for: document)
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Initialization code
        downloadStatusView.isHidden = true
        progressView.isHidden = true

        // setup tag list view
        tagListView.tokenBackgroundColor = .paLightRed
    }

    func updateDownloadStatus(for document: Document) {

        switch document.downloadStatus {
        case .local:
            downloadStatusView.isHidden = true
            progressView.isHidden = true
            progressView.progress = 1
        case .iCloudDrive:
            downloadStatusView.isHidden = false
            progressView.isHidden = true
            progressView.progress = 0
        case .downloading(let percentage):
            downloadStatusView.isHidden = false
            progressView.isHidden = false
            progressView.progress = percentage
        }
    }
}
