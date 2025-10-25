//
//  ShareViewController.swift
//  PDFArchiverShareExtension
//
//  Created by Julian Kahnert on 15.06.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import OSLog
import PDFKit
import Shared
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private static let log = Logger(subsystem: "PDFArchiverShareExtension", category: "ShareViewController")

    fileprivate enum ShareError: Error {
        case containerNotFound
        case noData
        case invalidData
    }

    private static let validUTIs: [UTType] = [
        .fileURL,
        .url,
        .pdf,
        .image
    ]

    @IBOutlet private weak var backgroundView: UIView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var checkmark: UIImageView!

    private var minTimeDeadline: DispatchTime?

    override func viewDidLoad() {
        super.viewDidLoad()

        backgroundView.layer.cornerRadius = 25
        activityIndicator.startAnimating()
        activityIndicator.hidesWhenStopped = true
        checkmark.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        minTimeDeadline = .now() + .milliseconds(750)
        Task(priority: .userInitiated) {
            await self.handleAttachments()
        }
    }

    // MARK: - Helper Functions

    private func complete(with error: (any Error)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: minTimeDeadline ?? .now()) { [weak self] in

            if error != nil {
                self?.checkmark.image = UIImage(systemName: "xmark.circle.fill")
            }

            self?.activityIndicator.isHidden = true
            self?.checkmark.isHidden = false

            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(600)) {
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }

    private func handleAttachments() async {
        do {
            // Migrate any documents from legacy temp location before processing new attachment
            await migrateLegacyDocuments()

            let url = Constants.tempDocumentURL
            try FileManager.default.createFolderIfNotExists(url)

            let inputItems = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
            var success = false

            // if we share e.g. 2 pictures, there is 1 inputItem with 2 attachments
            // if we share a pdf from a website, there are 2 inputItems (pdf/url) with 1 attachment
            for item in inputItems {
                for attachment in (item.attachments ?? []) {
                    let attachmentSuccess = try await attachment.saveData(at: url, with: Self.validUTIs)
                    success = success || attachmentSuccess
                }

                if success {
                    // just get the first attachment you can get
                    break
                }
            }

            var error: (any Error)?
            if !success {
                error = ShareError.invalidData
            }

            complete(with: error)
        } catch {
            complete(with: error)
        }
    }

    /// Migrates documents from the old temporary directory (used before App Group Container)
    /// to the new shared App Group Container location.
    /// This ensures documents shared via ShareExtension before the fix are not lost.
    private func migrateLegacyDocuments() async {
        // Old location: URL.temporaryDirectory/TempDocuments (extension-specific temp directory)
        let legacyTempURL = URL.temporaryDirectory.appendingPathComponent("TempDocuments")

        guard FileManager.default.directoryExists(at: legacyTempURL) else {
            Self.log.debug("No legacy temp directory found, skipping migration")
            return
        }

        Self.log.info("Found legacy temp directory, checking for documents to migrate")

        do {
            let legacyURLs = try FileManager.default.contentsOfDirectory(
                at: legacyTempURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )

            guard !legacyURLs.isEmpty else {
                Self.log.debug("No documents to migrate")
                // Clean up empty legacy directory
                try? FileManager.default.removeItem(at: legacyTempURL)
                return
            }

            // Ensure target directory exists
            try FileManager.default.createFolderIfNotExists(Constants.tempDocumentURL)

            var migratedCount = 0
            for legacyURL in legacyURLs {
                let targetURL = Constants.tempDocumentURL.appendingPathComponent(legacyURL.lastPathComponent)

                do {
                    // Check if file already exists at target
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        Self.log.warning("File already exists at target, removing legacy file", metadata: [
                            "file": "\(legacyURL.lastPathComponent)"
                        ])
                        try FileManager.default.removeItem(at: legacyURL)
                    } else {
                        // Move the file to the new location
                        try FileManager.default.moveItem(at: legacyURL, to: targetURL)
                        migratedCount += 1
                        Self.log.info("Migrated document", metadata: [
                            "from": "\(legacyURL.path)",
                            "to": "\(targetURL.path)"
                        ])
                    }
                } catch {
                    Self.log.error("Failed to migrate document", metadata: [
                        "file": "\(legacyURL.lastPathComponent)",
                        "error": "\(error)"
                    ])
                }
            }

            Self.log.info("Migration completed", metadata: [
                "migratedCount": "\(migratedCount)",
                "totalFound": "\(legacyURLs.count)"
            ])

            // Clean up legacy directory after migration
            try? FileManager.default.removeItem(at: legacyTempURL)

        } catch {
            Self.log.error("Failed to read legacy temp directory", metadata: ["error": "\(error)"])
        }
    }
}

extension NSItemProvider: @unchecked @retroactive Sendable {}
