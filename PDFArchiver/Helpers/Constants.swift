//
//  Constants.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_try

import Foundation

enum Constants {
    static let documentDatePlaceholder = "PDFARCHIVER-TEMP-DATE"
    static let documentDescriptionPlaceholder = "PDF-ARCHIVER-TEMP-DESCRIPTION-"
    static let documentTagPlaceholder = "PDFARCHIVERTEMPTAG"

    static var sentryDsn: String {
        return "https://" + (try! Configuration.value(for: "SENTRY_DSN"))
    }

    static var appStoreConnectSharedSecret: String {
        return try! Configuration.value(for: "APPSTORECONNECT_SHARED_SECRET")
    }

    static var logUser: String {
        return try! Configuration.value(for: "LOG_USER")
    }

    static var logPassword: String {
        return try! Configuration.value(for: "LOG_PASSWORD")
    }
}
