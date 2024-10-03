//
//  UserDefaults.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.08.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

extension UserDefaults: Log {

    enum Names: String, CaseIterable {
        case tutorialShown = "tutorial-v1"
        case lastSelectedTabName
        case pdfQuality
        case firstDocumentScanAlertPresented
        case lastAppUsagePermitted
        case archiveURL
        case untaggedURL
        case observedFolderURL
        case archivePathType
        case notSaveDocumentTagsAsPDFMetadata
        case documentTagsNotRequired
        case documentSpecificationNotRequired
    }

    enum PDFQuality: Float, CaseIterable {
        case lossless = 1.0
        case good = 0.75
        case normal = 0.5
        case small = 0.25

        static let defaultQualityIndex = 1  // e.g. "good"
    }

    static func shouldManipulatePdfDocument() -> Bool {
        if #available(iOS 17, macOS 14, *) {
            if #available(iOS 17.2, macOS 14.2, *) {
                // creation of PDFs is fixed in iOS 17.2
                return true
            } else {
                // iOS 17.0 to 17.1
                return false
            }
        } else {
            return true
        }
    }

    static var isInDemoMode: Bool {
        UserDefaults.standard.bool(forKey: "demoMode")
    }

    static var tutorialShown: Bool {
        get {
            appGroup.bool(forKey: Names.tutorialShown.rawValue)
        }
        set {
            appGroup.set(newValue, forKey: Names.tutorialShown.rawValue)
        }
    }

    static var firstDocumentScanAlertPresented: Bool {
        get {
            appGroup.bool(forKey: Names.firstDocumentScanAlertPresented.rawValue)
        }
        set {
            appGroup.set(newValue, forKey: Names.firstDocumentScanAlertPresented.rawValue)
        }
    }

    static var lastAppUsagePermitted: Bool {
        get {
            appGroup.bool(forKey: Names.lastAppUsagePermitted.rawValue)
        }
        set {
            appGroup.set(newValue, forKey: Names.lastAppUsagePermitted.rawValue)
        }
    }

    static var lastSelectedTab: TabType {
        get {
            guard let name = appGroup.string(forKey: Names.lastSelectedTabName.rawValue),
                let tab = TabType(rawValue: name) else { return .scan }
            return tab
        }
        set {
            appGroup.set(newValue.rawValue, forKey: Names.lastSelectedTabName.rawValue)
        }
    }

    static var pdfQuality: PDFQuality {
        get {
            var value = appGroup.float(forKey: Names.pdfQuality.rawValue)

            // set default to 0.75
            if value == 0.0 {
                value = PDFQuality.allCases[PDFQuality.defaultQualityIndex].rawValue
            }

            guard let level = PDFQuality(rawValue: value) else { fatalError("Could not parse level from value \(value).") }
            return level
        }
        set {
            log.info("PDF Quality Changed.", metadata: ["quality": "\(newValue.rawValue)"])
            appGroup.set(newValue.rawValue, forKey: Names.pdfQuality.rawValue)
        }
    }

    static var archiveURL: URL? {
        get {
            appGroup.object(forKey: Names.archiveURL.rawValue) as? URL
        }
        set {
            appGroup.set(newValue, forKey: Names.archiveURL.rawValue)
        }
    }

    static var untaggedURL: URL? {
        get {
            appGroup.object(forKey: Names.untaggedURL.rawValue) as? URL
        }
        set {
            appGroup.set(newValue, forKey: Names.untaggedURL.rawValue)
        }
    }

    #if os(macOS)
    static var observedFolderURL: URL? {
        get {
            guard let bookmarkData = appGroup.object(forKey: Names.observedFolderURL.rawValue) as? Data else { return nil }

            do {
                var staleBookmarkData = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
                if staleBookmarkData {
                    appGroup.set(nil, forKey: Names.observedFolderURL.rawValue)
                    log.errorAndAssert("Found stale bookmark data.")
                    return nil
                }
                return url
            } catch {
                appGroup.set(nil, forKey: Names.observedFolderURL.rawValue)
                log.errorAndAssert("Failed to get observedFolderURL", metadata: ["error": "\(error)"])
                NotificationCenter.default.postAlert(error)
                return nil
            }
        }
        set {
            do {
                if let url = newValue {
                    let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    appGroup.set(bookmark, forKey: Names.observedFolderURL.rawValue)
                } else {
                    appGroup.set(nil, forKey: Names.observedFolderURL.rawValue)
                }
            } catch {
                appGroup.set(nil, forKey: Names.observedFolderURL.rawValue)
                log.errorAndAssert("Failed to set observedFolderURL.", metadata: ["error": "\(error)"])
                NotificationCenter.default.postAlert(error)
            }
        }
    }
    #endif

    static var notSaveDocumentTagsAsPDFMetadata: Bool {
        get {
            appGroup.bool(forKey: Names.notSaveDocumentTagsAsPDFMetadata.rawValue)
        }
        set {
            appGroup.set(newValue, forKey: Names.notSaveDocumentTagsAsPDFMetadata.rawValue)
        }
    }

    static var documentTagsNotRequired: Bool {
        get {
            appGroup.bool(forKey: Names.documentTagsNotRequired.rawValue)
        }
        set {
            appGroup.set(newValue, forKey: Names.documentTagsNotRequired.rawValue)
        }
    }

    static var documentSpecificationNotRequired: Bool {
        get {
            appGroup.bool(forKey: Names.documentSpecificationNotRequired.rawValue)
        }
        set {
            appGroup.set(newValue, forKey: Names.documentSpecificationNotRequired.rawValue)
        }
    }

    func setObject<T: Encodable>(_ object: T?, forKey key: Names) throws {
        guard let object = object else {
            set(nil, forKey: key.rawValue)
            return
        }
        let data = try JSONEncoder().encode(object)
        set(data, forKey: key.rawValue)
    }

    func getObject<T: Decodable>(forKey key: Names) throws -> T? {
        guard let data = object(forKey: key.rawValue) as? Data else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Migration

    static var appGroup: UserDefaults {
        // swiftlint:disable:next force_unwrapping
//        UserDefaults(suiteName: Constants.sharedContainerIdentifier)!
        UserDefaults.standard
    }
}
