//
//  Constants.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

enum Constants {
//    static let sharedContainerIdentifier = "group.PDFArchiverShared"

    static let documentDatePlaceholder = "PDFARCHIVER-TEMP-DATE"
    static let documentDescriptionPlaceholder = "PDF-ARCHIVER-TEMP-DESCRIPTION-"
    static let documentTagPlaceholder = "PDFARCHIVERTEMPTAG"

    static let mailRecipient = "support@pdf-archiver.io"
    static let mailSubject = "PDF Archiver: Support"

    static let inAppPurchaseGroupId = "20516661"

//    static let appGroupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.sharedContainerIdentifier)!
//    static let tempDocumentURL = appGroupContainerURL.appendingPathComponent("TempDocuments")
    static let tempDocumentURL = URL.temporaryDirectory.appendingPathComponent("TempDocuments")
}
