//
//  ShareViewController.swift
//  PDFArchiverShareExtension
//
//  Created by Julian Kahnert on 15.06.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import PDFKit
import UIKit
import ArchiveSharedConstants

final class ShareViewController: UIViewController {

    fileprivate enum ShareError: Error {
        case timeout
        case containerNotFound
        case noData
        case invalidData
    }

    private static let validUTIs = [
        "public.file-url",
        "public.url",
        "com.adobe.pdf",
        "public.image"
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
            for item in inputItems {
                for attachment in (item.attachments ?? []) {
                    let attachmentSuccess = try saveData(from: attachment, at: url)
                    success = success || attachmentSuccess
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

    private func saveData(from attachment: NSItemProvider, at url: URL) throws -> Bool {
        var error: Error?
        var data: Data?

        for uti in Self.validUTIs where attachment.hasItemConformingToTypeIdentifier(uti) {
            do {
                data = try attachment.syncLoadItem(forTypeIdentifier: uti)
            } catch let inputError {
                error = inputError
            }

            guard let data = data else { continue }

            if UIImage(data: data) != nil {
                let fileUrl = url.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpeg")
                try data.write(to: fileUrl)
                return true
            } else if PDFDocument(data: data) != nil {
                let fileUrl = url.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
                try data.write(to: fileUrl)
                return true
            }
        }

        if let err = error {
            throw err
        }

        return false
    }
}

fileprivate extension NSItemProvider {
    func syncLoadItem(forTypeIdentifier uti: String) throws -> Data? {
        var data: Data?
        var error: Error?
        let semaphore = DispatchSemaphore(value: 0)
        self.loadItem(forTypeIdentifier: uti, options: nil) { rawData, rawError in
            defer {
                semaphore.signal()
            }
            if let rawError = rawError {
                error = rawError
            }

            if let url = rawData as? URL {
                do {
                    data = try Data(contentsOf: url)
                } catch let inputError {
                    error = inputError
                }
            } else if let inputData = rawData as? Data {
                data = inputData
            } else if let image = rawData as? UIImage {
                data = image.jpegData(compressionQuality: 1)
            }
        }
        let timeoutResult = semaphore.wait(timeout: .now() + .seconds(10))
        guard timeoutResult == .success else {
            throw ShareViewController.ShareError.timeout
        }

        if let error = error {
            throw error
        }

        return data
    }
}
