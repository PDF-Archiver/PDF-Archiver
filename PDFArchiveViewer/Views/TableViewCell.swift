//
//  TableViewCell.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 05.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {
    @IBOutlet weak var tileLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var downloadView: UIView!

    var document: Document?

    override func layoutSubviews() {
        super.layoutSubviews()
        if let document = self.document {
            self.tileLabel.text = document.specification.replacingOccurrences(of: "-", with: " ")
            self.dateLabel.text = DateFormatter.localizedString(from: document.date, dateStyle: .medium, timeStyle: .none)

            for view in self.downloadView.subviews {
                view.removeFromSuperview()
            }

            var view: UIView
            switch document.downloadStatus {
            case .local:
                view = UIView()
            case .iCloudDrive:
                view = UIImageView(image: #imageLiteral(resourceName: "apple-icloud"))
            case .downloading:
                let indicatorView = UIActivityIndicatorView()
                indicatorView.activityIndicatorViewStyle = .gray
                indicatorView.translatesAutoresizingMaskIntoConstraints = true

                // Springs and struts
                indicatorView.center = CGPoint(x: self.downloadView.bounds.midX, y: self.downloadView.bounds.midY)
                indicatorView.autoresizingMask = [
                    .flexibleLeftMargin,
                    .flexibleRightMargin,
                    .flexibleTopMargin,
                    .flexibleBottomMargin]

                indicatorView.startAnimating()
                view = indicatorView
            }
            self.downloadView.addSubview(view)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }

}
