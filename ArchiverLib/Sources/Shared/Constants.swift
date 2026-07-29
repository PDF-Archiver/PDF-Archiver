//
//  Constants.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

nonisolated public enum Constants {
    public static let mailRecipient = "support@pdf-archiver.io"
    public static let mailSubject = "PDF Archiver: Support"

    // Staging area for documents before they are processed and moved to the archive:
    // 1. Share Extension: imported PDFs are stored here (via App Group on iOS) for the main app to pick up
    // 2. PDF Processing: scanned images and PDFs are temporarily saved here during OCR and quality adjustment
    // 3. Settings: can be cleared manually via Expert Settings or during a full app reset
    #if os(macOS)
    public static let tempDocumentURL = URL.temporaryDirectory.appendingPathComponent("TempDocuments")
    #else
    public static let sharedContainerIdentifier = "group.PDFArchiverShared"
    // swiftlint:disable:next force_unwrapping
    static let appGroupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.sharedContainerIdentifier)!
    public static let tempDocumentURL = appGroupContainerURL.appendingPathComponent("TempDocuments")
    #endif
}
