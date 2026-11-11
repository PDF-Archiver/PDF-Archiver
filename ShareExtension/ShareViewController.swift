//
//  ShareViewController.swift
//  PDFArchiverShareExtension
//
//  Created by Julian Kahnert on 15.06.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import ArchiverModels
import Logging
import PDFKit
import Shared
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController, Log {
    // The extension process can create this controller more than once, and a second bootstrap traps.
    private static let loggingBootstrap: Void = LoggingSystem.bootstrap(OSLogHandler.init)

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

    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var checkmark: UIImageView!

    private var minTimeDeadline: ContinuousClock.Instant?

    override func viewDidLoad() {
        super.viewDidLoad()
        _ = Self.loggingBootstrap

        activityIndicator.startAnimating()
        activityIndicator.hidesWhenStopped = true
        checkmark.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        minTimeDeadline = .now + .milliseconds(750)
        Task(priority: .userInitiated) {
            await self.handleAttachments()
        }
    }

    // MARK: - Helper Functions

    private func complete(with error: (any Error)? = nil) async {
        // `try?`: the request has to complete even if the sleep ends early.
        try? await Task.sleep(until: minTimeDeadline ?? .now, clock: .continuous)

        if error != nil {
            checkmark.image = UIImage(systemName: "xmark.circle.fill")
        }

        activityIndicator.isHidden = true
        checkmark.isHidden = false

        try? await Task.sleep(for: .milliseconds(600))
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func handleAttachments() async {
        do {
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

            await complete(with: error)
        } catch {
            await complete(with: error)
        }
    }
}

// Unchecked: Foundation does not mark `NSItemProvider` `Sendable`, though its loading API is
// asynchronous and callable from any thread. This extension only loads from the providers the host
// app handed over and never registers items on them. Remove once Foundation declares the conformance.
extension NSItemProvider: @unchecked @retroactive Sendable {}

extension ShareViewController.ShareError: LogSafeError {
    var logDescription: String { "\(self)" }
}
