//
//  Constants.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

public nonisolated enum Constants {
    public static let documentDatePlaceholder = "PDFARCHIVER-TEMP-DATE"
    public static let documentDescriptionPlaceholder = "PDF-ARCHIVER-TEMP-DESCRIPTION-"
    public static let documentTagPlaceholder = "PDFARCHIVERTEMPTAG"

    public static let mailRecipient = "support@pdf-archiver.io"
    public static let mailSubject = "PDF Archiver: Support"

    #if os(macOS)
    public static let tempDocumentURL = URL.temporaryDirectory.appendingPathComponent("TempDocuments")
    #else
    public static let sharedContainerIdentifier = "group.PDFArchiverShared"
    // swiftlint:disable:next force_unwrapping
    static let appGroupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.sharedContainerIdentifier)!
    public static let tempDocumentURL = appGroupContainerURL.appendingPathComponent("TempDocuments")
    #endif
}
