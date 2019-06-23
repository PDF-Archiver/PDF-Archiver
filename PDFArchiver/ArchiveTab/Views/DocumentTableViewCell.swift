//
//  DocumentTableViewCell.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 12.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import TagListView
import UIKit

class DocumentTableViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var tagListView: TagListView!
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
                tagListView.removeAllTags()
                let documentTags = Array(document.tags).sorted { $0.name < $1.name }
                tagListView.addTags(documentTags.map { $0.name })

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
        tagListView.alignment = .right
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        // cascade highlight
        tagListView.tagViews.forEach {
            $0.isSelected = highlighted
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // cascade selection
        tagListView.tagViews.forEach {
            $0.isSelected = selected
        }
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
