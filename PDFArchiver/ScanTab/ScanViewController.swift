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

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(imageQueueLengthChange),
                                               name: .imageProcessingQueueLength,
                                               object: nil)

        // trigger processing (if temp images exist)
        triggerProcessing()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // save the selected index for the next app start
        UserDefaults.standard.set(tabBarController?.selectedIndex ?? 2, forKey: Constants.UserDefaults.lastSelectedTabIndex.rawValue)

        // show the processing indicator, if documents are currently processed
        updateProcessingIndicator(with: ImageConverter.getOperationCount())

        // show subscription view controller, if no subscription was found
        if !IAP.service.appUsagePermitted() {
            let viewController = SubscriptionViewController {
                self.tabBarController?.selectedIndex = self.tabBarController?.getViewControllerIndex(with: "ArchiveTab") ?? 2
            }
            present(viewController, animated: animated)
        }
    }

    // MARK: - Helper Functions

    @objc
    private func imageQueueLengthChange(_ notification: Notification) {
        guard let count = notification.object as? Int else {
            let object = notification.object as Any
            assertionFailure("Invalid object: \(object)")
            return
        }

        updateProcessingIndicator(with: count)
    }

    private func updateProcessingIndicator(with count: Int) {
        DispatchQueue.main.async {
            self.processingIndicatorView.isHidden = count < 1
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
        guard let untaggedPath = StorageHelper.Paths.untaggedPath else {
            self.present(StorageHelper.Paths.iCloudDriveAlertController, animated: true, completion: nil)
            return
        }
        ImageConverter.saveProcessAndSaveTempImages(at: untaggedPath)
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

        // save image
        do {
            try StorageHelper.save([image])
        } catch {
            assertionFailure("Could not save temp images with error:\n\(error.localizedDescription)")
            let alert = UIAlertController(title: NSLocalizedString("not-saved-images.title", comment: "Alert VC: Title"), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Button confirmation label"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }

        // notify ImageConverter
        triggerProcessing()

        // show processing indicator instantly
        updateProcessingIndicator(with: ImageConverter.getOperationCount())
    }

    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        // user tapped 'Cancel' on the scanner
        scanner.dismiss(animated: true)
    }

}

extension  UITabBarController {
    func getViewControllerIndex(with restorationIdentifier: String) -> Int? {
        return viewControllers?.firstIndex { $0.restorationIdentifier == restorationIdentifier }
    }
}
