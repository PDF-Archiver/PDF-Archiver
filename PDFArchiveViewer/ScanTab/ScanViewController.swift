//
//  ScanViewController.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 21.02.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import WeScan

class ScanViewController: UIViewController, Logging {

    private let scannerViewController = ImageScannerController()

    @IBOutlet private var scanView: UIView!

    @IBAction private func scanButtonTapped(_ sender: UIButton) {
        present(scannerViewController, animated: true)
    }

    @IBAction private func tagButtonTapped(_ sender: UIButton) {
        self.tabBarController?.selectedIndex = 1
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        scannerViewController.imageScannerDelegate = self
        scanView.subviews.forEach { $0.layer.cornerRadius = 10 }
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

        guard let containerUrl = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { fatalError("Could not find a iCloud Drive url.") }

        // convert and save image on a background thread
        DispatchQueue.global(qos: .background).async {
            ImageConverter.process([image], saveAt: containerUrl.appendingPathComponent("Documents").appendingPathComponent("untagged"))
        }
    }

    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        // The user tapped 'Cancel' on the scanner
        // You are responsible for dismissing the ImageScannerController
        scanner.dismiss(animated: true)
    }
}
