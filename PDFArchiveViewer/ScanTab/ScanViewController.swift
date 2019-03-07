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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let scannerViewController = ImageScannerController()
        scannerViewController.imageScannerDelegate = self
        present(scannerViewController, animated: animated)
        // TODO: this might only be presented in the current view
    }

    fileprivate func jumpToTagTab() {
        // switch to the tag view controller
        self.tabBarController?.selectedIndex = 1

        // TODO: animation looks crappy
        // TODO: index should not be hardcoded
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
            ImageConverter.process(image, saveAt: containerUrl.appendingPathComponent("Documents").appendingPathComponent("untagged"))
        }

        // process finished: jump to other tab
        jumpToTagTab()

        // TODO: add alert view if we want to scan another document
        //        let actionSheet = UIAlertController(title: "Would you like to scan another image or start tagging?", message: nil, preferredStyle: .actionSheet)
        //
        //        let tagAction = UIAlertAction(title: "Scan", style: .default, handler: nil)
        //
        //        let scanAction = UIAlertAction(title: "Select", style: .default) { (_) in
        //            self.jumpToTagTab()
        //        }
        //
        //        actionSheet.addAction(tagAction)
        //        actionSheet.addAction(scanAction)
        //
        //        present(actionSheet, animated: true)
    }

    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        // The user tapped 'Cancel' on the scanner
        // You are responsible for dismissing the ImageScannerController
        scanner.dismiss(animated: true)

        jumpToTagTab()
    }
}
