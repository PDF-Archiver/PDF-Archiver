//
//  ShareViewController.swift
//  PDFArchiverShareExtension
//
//  Created by Julian Kahnert on 15.06.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import PDFKit
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

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
        DispatchQueue.global(qos: .userInitiated).async {
            self.handleAttachments()
        }
    }

    // MARK: - Helper Functions

    private func complete(with error: Error? = nil) {
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

    private func handleAttachments() {
        do {
            let url = PathConstants.extensionTempPdfURL
            let inputItems = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
            var success = false

            // if we share e.g. 2 pictures, there is 1 inputItem with 2 attachments
            // if we share a pdf from a website, there are 2 inputItems (pdf/url) with 1 attachment
            for item in inputItems {
                for attachment in (item.attachments ?? []) {
                    let attachmentSuccess = try attachment.saveData(at: url, with: Self.validUTIs)
                    success = success || attachmentSuccess
                }

                if success {
                    // just get the first attachment you can get
                    break
                }
            }

            var error: Error?
            if !success {
                error = ShareError.invalidData
            }

            complete(with: error)
        } catch {
            complete(with: error)
        }
    }
}
