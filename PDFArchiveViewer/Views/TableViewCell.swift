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
    @IBOutlet weak var downloadImageView: UIImageView!

    var document: Document?

    override func layoutSubviews() {
        super.layoutSubviews()
        if let document = self.document {
            self.tileLabel.text = document.specification.replacingOccurrences(of: "-", with: " ")
            self.dateLabel.text = DateFormatter.localizedString(from: document.date, dateStyle: .medium, timeStyle: .none)
            if !document.isLocal {
                self.downloadImageView.image = #imageLiteral(resourceName: "apple-icloud")
            }
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
