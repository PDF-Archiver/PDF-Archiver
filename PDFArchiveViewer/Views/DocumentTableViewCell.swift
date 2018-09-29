//
//  DocumentTableViewCell.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 12.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import UIKit

class DocumentTableViewCell: UITableViewCell {
    @IBOutlet weak var tileLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var tagLabel: UILabel!
    @IBOutlet weak var downloadImageView: UIImageView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    var document: Document?

    override func layoutSubviews() {
        super.layoutSubviews()
        if let document = self.document {
            self.tileLabel.text = document.specification.replacingOccurrences(of: "-", with: " ")
            self.dateLabel.text = DateFormatter.localizedString(from: document.date, dateStyle: .medium, timeStyle: .none)
            self.tagLabel.text = document.tags.map { String($0.name) }.joined(separator: " ")

            switch document.downloadStatus {
            case .local:
                self.downloadImageView.isHidden = true
                self.activityIndicatorView.isHidden = true
                self.activityIndicatorView.stopAnimating()
            case .iCloudDrive:
                self.downloadImageView.isHidden = false
                self.activityIndicatorView.isHidden = true
                self.activityIndicatorView.stopAnimating()
            case .downloading:
                self.downloadImageView.isHidden = true
                self.activityIndicatorView.isHidden = false
                self.activityIndicatorView.startAnimating()
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Initialization code
        self.downloadImageView.isHidden = true
        self.activityIndicatorView.isHidden = true
        self.activityIndicatorView.activityIndicatorViewStyle = .gray
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
}
