//
//  Constants.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

enum Constants {
    static let documentDatePlaceholder = "PDFARCHIVER-TEMP-DATE"
    static let documentDescriptionPlaceholder = "PDF-ARCHIVER-TEMP-DESCRIPTION-"
    static let documentTagPlaceholder = "PDFARCHIVERTEMPTAG"

    // MARK: - UserDefaults Keys
    enum UserDefaults: String {
        case tutorialShown
    }
}
