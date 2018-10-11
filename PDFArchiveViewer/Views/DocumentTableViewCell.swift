//
//  DocumentTableViewCell.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 12.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import TagListView
import UIKit

class DocumentTableViewCell: UITableViewCell {
    @IBOutlet weak var tileLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var tagListView: TagListView!
    @IBOutlet weak var downloadImageView: UIImageView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    var document: Document?

    override func layoutSubviews() {

        // layout subviews to get the right separators
        super.layoutSubviews()

        if let document = document {

            // update title + date
            tileLabel.text = document.specificationCapitalized
            dateLabel.text = DateFormatter.localizedString(from: document.date, dateStyle: .medium, timeStyle: .none)

            // update the document tags
            tagListView.removeAllTags()
            let documentTags = Array(document.tags).sorted { $0.name < $1.name }
            tagListView.addTags(documentTags.map { $0.name })

            // update download status
            switch document.downloadStatus {
            case .local:
                downloadImageView.isHidden = true
                activityIndicatorView.isHidden = true
                activityIndicatorView.stopAnimating()
            case .iCloudDrive:
                downloadImageView.isHidden = false
                activityIndicatorView.isHidden = true
                activityIndicatorView.stopAnimating()
            case .downloading:
                downloadImageView.isHidden = true
                activityIndicatorView.isHidden = false
                activityIndicatorView.startAnimating()
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Initialization code
        downloadImageView.isHidden = true
        activityIndicatorView.isHidden = true
        activityIndicatorView.style = .gray

        // setup tag list view
        tagListView.tagBackgroundColor = UIColor(named: "TagBackground") ?? .darkGray
        tagListView.alignment = .right
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
}
