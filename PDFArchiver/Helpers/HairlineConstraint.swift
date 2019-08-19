//
//  HairlineConstraint.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.08.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

class HairlineConstraint: NSLayoutConstraint {

    static let height = 1.0 / UIScreen.main.scale

    override func awakeFromNib() {
        super.awakeFromNib()

        self.constant = HairlineConstraint.height
    }
}
