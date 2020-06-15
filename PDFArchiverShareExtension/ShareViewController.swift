//
//  ShareViewController.swift
//  PDFArchiverShareExtension
//
//  Created by Julian Kahnert on 15.06.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import PDFKit
import UIKit

class ShareViewController: UIViewController {
    
    private enum ShareError: Error {
        case timeout
        case containerNotFound
        case noData
    }

    
    private static let sharedContainerIdentifier = "group.PDFArchiverShared"
    
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
            guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.sharedContainerIdentifier) else { throw ShareError.containerNotFound }
            let inputItems = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
            for item in inputItems {
                for attachment in (item.attachments ?? []) {
                    try saveData(from: attachment, at: url)
                }
            }

            complete()
        } catch {
            complete(with: error)
        }
    }
    
    private func saveData(from attachment: NSItemProvider, at url: URL) throws {
        var error: Error?
        var data: Data?
        
        let semaphore = DispatchSemaphore(value: 0)
        if attachment.registeredTypeIdentifiers.contains("com.adobe.pdf") {
            attachment.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { (rawData, inputError) in
                defer {
                    semaphore.signal()
                }
                error = inputError
                guard inputError == nil else { return }
                
                guard let inputData = rawData as? Data,
                    let documentData = PDFDocument(data: inputData)?.dataRepresentation() else { return }
                
                data = documentData
            }
        } else if attachment.canLoadObject(ofClass: UIImage.self) {
            attachment.loadObject(ofClass: UIImage.self) { (rawImage, inputError) in
                defer {
                    semaphore.signal()
                }
                error = inputError
                guard inputError == nil,
                    let image = rawImage as? UIImage else { return }
                    
                data = image.jpegData(compressionQuality: 1)
            }
        } else {
            return
        }
        
        let timeoutResult = semaphore.wait(timeout: .now() + .seconds(10))
        guard timeoutResult == .success else {
            throw ShareError.timeout
        }
        
        if let err = error {
            throw err
        }
        
        guard let outputData = data else {
            throw ShareError.noData
        }
        
        let fileUrl = url.appendingPathComponent(UUID().uuidString)
        try outputData.write(to: fileUrl)
    }
}
