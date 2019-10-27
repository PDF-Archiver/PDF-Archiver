//
//  ScanViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.02.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import AVFoundation
import os.log
import StoreKit
import VisionKit

class ScanViewController: UIViewController, SystemLogging {

    private var scannerViewController: VNDocumentCameraViewController?

    @IBOutlet private weak var processingIndicatorView: UIView!
    @IBOutlet private weak var progressLabel: UILabel!
    @IBOutlet private weak var progressView: UIProgressView!

    @IBAction private func scanButtonTapped(_ sender: UIButton) {

        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizationStatus ==  .denied || authorizationStatus == .restricted {
            os_log("Authorization status blocks camera access. Switch to preferences.", log: ScanViewController.log, type: .info)
            alertCameraAccessNeeded()
        } else {

            Log.send(.info, "Start scanning a document.")
            scannerViewController = VNDocumentCameraViewController()

            guard let scannerViewController = scannerViewController else { return }
            scannerViewController.delegate = self
            present(scannerViewController, animated: true)

            // stop current image processing
            ImageConverter.shared.stopProcessing()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        processingIndicatorView.isHidden = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(imageQueueLengthChange),
                                               name: .imageProcessingQueue,
                                               object: nil)

        // show the processing indicator, if documents are currently processed
        if ImageConverter.shared.totalDocumentCount.value != 0 {
            updateProcessingIndicator(with: 0)
        }

        // trigger processing (if temp images exist)
        triggerProcessing()
    }

    // MARK: - Helper Functions

    @objc
    private func imageQueueLengthChange(_ notification: Notification) {

        if let documentProgress = notification.object as? Float {
            updateProcessingIndicator(with: documentProgress)
        } else {
            updateProcessingIndicator(with: nil)
        }
    }

    private func updateProcessingIndicator(with documentProgress: Float?) {
        DispatchQueue.main.async {

            // we do not need a progress view, if the number of total documents is 0
            let totalDocuments = ImageConverter.shared.totalDocumentCount.value
            let tmpDocumentProgress = totalDocuments == 0 ? nil : documentProgress

            if let documentProgress = tmpDocumentProgress {

                let completedDocuments = totalDocuments - ImageConverter.shared.getOperationCount()
                let progressString = "\(min(completedDocuments + 1, totalDocuments))/\(totalDocuments) (\(Int(documentProgress * 100))%)"

                self.processingIndicatorView.isHidden = false
                self.progressView.progress = (Float(completedDocuments) + documentProgress) / Float(totalDocuments)
                self.progressLabel.text = NSLocalizedString("ScanViewController.processing", comment: "") + progressString
            } else {
                self.processingIndicatorView.isHidden = true
                self.progressView.progress = 0
                self.progressLabel.text = NSLocalizedString("ScanViewController.processing", comment: "") + "0%"
            }
        }
    }

    private func alertCameraAccessNeeded() {

        let alert = UIAlertController(
            title: NSLocalizedString("Need Camera Access", comment: "Camera access in ScanViewController."),
            message: NSLocalizedString("Camera access is required to scan documents.", comment: "Camera access in ScanViewController."),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Camera access in ScanViewController."), style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Grant Access", comment: "Camera access in ScanViewController."), style: .cancel) { (_) -> Void in
            guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
            UIApplication.shared.open(settingsAppURL, options: [:], completionHandler: nil)
        })

        present(alert, animated: true, completion: nil)
    }

    private func triggerProcessing() {
        do {
            try StorageHelper.triggerProcessing()
        } catch {
            present(StorageHelper.Paths.iCloudDriveAlertController, animated: true, completion: nil)
        }
    }

    private func testAppUsagePermitted() -> Bool {

        let isPermitted = IAP.service.appUsagePermitted()

        // show subscription view controller, if no subscription was found
        if !isPermitted {
            DispatchQueue.main.async {

                let alert = UIAlertController(title: NSLocalizedString("ScanViewController.noSubscription.title", comment: ""),
                                              message: NSLocalizedString("ScanViewController.noSubscription.message", comment: ""),
                                              preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    let viewController = SubscriptionViewController {
                        self.tabBarController?.selectedIndex = self.tabBarController?.getViewControllerIndex(with: "ArchiveTab") ?? 2
                    }
                    (self.tabBarController ?? self).present(viewController, animated: true)
                })
                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { _ in
                    self.tabBarController?.selectedIndex = self.tabBarController?.getViewControllerIndex(with: "ArchiveTab") ?? 2
                })
                self.present(alert, animated: true, completion: nil)
            }
        }

        return isPermitted
    }
}

extension ScanViewController: VNDocumentCameraViewControllerDelegate {

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {

        ImageConverter.shared.startProcessing()

        Log.send(.info, "Did finish scanning with result.")

        // The user successfully scanned an image, which is available in the ImageScannerResults
        // You are responsible for dismissing the ImageScannerController
        controller.dismiss(animated: true)

        // The scanned pages seemed to be reversed!
        var images = [UIImage]()
        for index in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: index)
            images.append(image)
        }

        // validate subscription
        guard testAppUsagePermitted() else { return }

        // save images in reversed order to fix the API output order
        do {
            try StorageHelper.save(images)
        } catch {
            assertionFailure("Could not save temp images with error:\n\(error.localizedDescription)")
            let alert = UIAlertController(title: NSLocalizedString("not-saved-images.title", comment: "Alert VC: Title"), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Button confirmation label"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }

        // notify ImageConverter
        triggerProcessing()

        // show processing indicator instantly
        updateProcessingIndicator(with: Float(0))
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        ImageConverter.shared.startProcessing()

        // user tapped 'Cancel' on the scanner
        controller.dismiss(animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        ImageConverter.shared.startProcessing()

        // You are responsible for carefully handling the error
        os_log("Selected Document: %@", log: ScanViewController.log, type: .error, error.localizedDescription)
        Log.send(.error, "Scan did fail with error.", extra: ["error": error.localizedDescription])
        controller.dismiss(animated: true)
    }
}

extension  UITabBarController {
    func getViewControllerIndex(with restorationIdentifier: String) -> Int? {
        return viewControllers?.firstIndex { $0.restorationIdentifier == restorationIdentifier }
    }
}
