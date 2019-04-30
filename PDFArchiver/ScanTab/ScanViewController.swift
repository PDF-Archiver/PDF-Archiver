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
import WeScan

class ScanViewController: UIViewController, Logging {

    private var scannerViewController: ImageScannerController?

    @IBOutlet weak var processingIndicatorView: UIView!

    @IBAction private func scanButtonTapped(_ sender: UIButton) {

        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizationStatus ==  .denied || authorizationStatus == .restricted {
            os_log("Authorization status blocks camera access. Switch to preferences.", log: ScanViewController.log, type: .info)
            alertCameraAccessNeeded()
        } else {
            scannerViewController = ImageScannerController()

            guard let scannerViewController = scannerViewController else { return }
            scannerViewController.imageScannerDelegate = self
            present(scannerViewController, animated: true)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        processingIndicatorView.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // show the processing indicator, if documents are currently processed
        updateProcessingIndicator()

        // show subscription view controller, if no subscription was found
        if !IAP.service.appUsagePermitted() {
            let viewController = SubscriptionViewController {
                self.tabBarController?.selectedIndex = self.tabBarController?.getViewControllerIndex(with: "ArchiveTab") ?? 2
            }
            present(viewController, animated: animated)
        }
    }

    // MARK: - Helper Functions

    private func updateProcessingIndicator() {
        DispatchQueue.main.async {
            self.processingIndicatorView.isHidden = ImageConverter.getOperationCount() == 0
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
            guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsAppURL, options: [:], completionHandler: nil)
        })

        present(alert, animated: true, completion: nil)
    }
}

extension ScanViewController: ImageScannerControllerDelegate {

    func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error) {
        // You are responsible for carefully handling the error
        os_log("Selected Document: %@", log: ScanViewController.log, type: .error, error.localizedDescription)
    }

    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults) {
        // The user successfully scanned an image, which is available in the ImageScannerResults
        // You are responsible for dismissing the ImageScannerController
        scanner.dismiss(animated: true)

        let image: UIImage
        if results.doesUserPreferEnhancedImage,
            let enhancedImage = results.enhancedImage {

            // try to get the greyscaled and enhanced image, if the user
            image = enhancedImage
        } else {

            // use cropped and deskewed image otherwise
            image = results.scannedImage
        }

        guard let untaggedPath = Constants.untaggedPath else {
            assertionFailure("Could not find a iCloud Drive url.")
            self.present(Constants.alertController, animated: true, completion: nil)
            return
        }

        // convert and save image on a background thread
        ImageConverter.process([image], saveAt: untaggedPath) {
            // hide processing indicator after the processing has completed
            self.updateProcessingIndicator()
        }

        // show processing indicator instantly
        updateProcessingIndicator()
    }

    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        // The user tapped 'Cancel' on the scanner
        // You are responsible for dismissing the ImageScannerController
        scanner.dismiss(animated: true)
    }
}

extension  UITabBarController {
    func getViewControllerIndex(with restorationIdentifier: String) -> Int? {
        return viewControllers?.firstIndex { $0.restorationIdentifier == restorationIdentifier }
    }
}
