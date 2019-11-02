//
//  ScanTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Combine
import Foundation
import os.log
import VisionKit

class ScanTabViewModel: NSObject, ObservableObject {
    @Published var showDocumentScan: Bool = false
    @Published var progressValue: Float = 0.0
    @Published var progressLabel: String = ""

    private var disposables = Set<AnyCancellable>()

    override init() {
        super.init()

        // show the processing indicator, if documents are currently processed
        if ImageConverter.shared.totalDocumentCount.value != 0 {
            updateProcessingIndicator(with: 0)
        }

        // trigger processing (if temp images exist)
        triggerProcessing()

        NotificationCenter.default.publisher(for: .imageProcessingQueue)
            .sink { notification in
                if let documentProgress = notification.object as? Float {
                    self.updateProcessingIndicator(with: documentProgress)
                } else {
                    self.updateProcessingIndicator(with: nil)
                }
            }
            .store(in: &disposables)
    }

    func startScanning() {
        Log.send(.info, "Start scanning a document.")
        showDocumentScan.toggle()

        // stop current image processing
        ImageConverter.shared.stopProcessing()
    }

    func process(_ images: [UIImage]?) {

        ImageConverter.shared.startProcessing()
        showDocumentScan = false

        guard let images = images else { return }

        // validate subscription
        guard testAppUsagePermitted() else { return }

        // save images in reversed order to fix the API output order
        do {
            try StorageHelper.save(images)
        } catch {
            // TODO: handle error
//            assertionFailure("Could not save temp images with error:\n\(error.localizedDescription)")
//            let alert = UIAlertController(title: NSLocalizedString("not-saved-images.title", comment: "Alert VC: Title"), message: error.localizedDescription, preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Button confirmation label"), style: .default, handler: nil))
//            present(alert, animated: true, completion: nil)
        }

        // notify ImageConverter
        triggerProcessing()

        // show processing indicator instantly
        updateProcessingIndicator(with: Float(0))
    }

    // MARK: - Helper Functions

    private func triggerProcessing() {
        do {
            try StorageHelper.triggerProcessing()
        } catch {
            // TODO: handle error
//            present(StorageHelper.Paths.iCloudDriveAlertController, animated: true, completion: nil)
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

                self.progressValue = (Float(completedDocuments) + documentProgress) / Float(totalDocuments)
                self.progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + progressString
            } else {
                self.progressValue = 0
                self.progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + "0%"
            }
        }
    }

    private func testAppUsagePermitted() -> Bool {

        let isPermitted = IAP.service.appUsagePermitted()

        // show subscription view controller, if no subscription was found
//        if !isPermitted {
//            // TODO: handle permission error
//            DispatchQueue.main.async {
//
//                let alert = UIAlertController(title: NSLocalizedString("ScanViewController.noSubscription.title", comment: ""),
//                                              message: NSLocalizedString("ScanViewController.noSubscription.message", comment: ""),
//                                              preferredStyle: .alert)
//
//                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
//                    let viewController = SubscriptionViewController {
//                        self.tabBarController?.selectedIndex = self.tabBarController?.getViewControllerIndex(with: "ArchiveTab") ?? 2
//                    }
//                    (self.tabBarController ?? self).present(viewController, animated: true)
//                })
//                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { _ in
//                    self.tabBarController?.selectedIndex = self.tabBarController?.getViewControllerIndex(with: "ArchiveTab") ?? 2
//                })
//                self.present(alert, animated: true, completion: nil)
//            }
//        }

        return isPermitted
    }
}



//    @IBAction private func scanButtonTapped(_ sender: UIButton) {
//
//        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
//        if authorizationStatus ==  .denied || authorizationStatus == .restricted {
//            os_log("Authorization status blocks camera access. Switch to preferences.", log: ScanViewController.log, type: .info)
//            alertCameraAccessNeeded()
//        } else {
//
//            Log.send(.info, "Start scanning a document.")
//            scannerViewController = VNDocumentCameraViewController()
//
//            guard let scannerViewController = scannerViewController else { return }
//            scannerViewController.delegate = self
//            present(scannerViewController, animated: true)
//
//            // stop current image processing
//            ImageConverter.shared.stopProcessing()
//        }
//    }
//
//    private func alertCameraAccessNeeded() {
//
//        let alert = UIAlertController(
//            title: NSLocalizedString("Need Camera Access", comment: "Camera access in ScanViewController."),
//            message: NSLocalizedString("Camera access is required to scan documents.", comment: "Camera access in ScanViewController."),
//            preferredStyle: .alert
//        )
//
//        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Camera access in ScanViewController."), style: .default, handler: nil))
//        alert.addAction(UIAlertAction(title: NSLocalizedString("Grant Access", comment: "Camera access in ScanViewController."), style: .cancel) { (_) -> Void in
//            guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
//            UIApplication.shared.open(settingsAppURL, options: [:], completionHandler: nil)
//        })
//
//        present(alert, animated: true, completion: nil)
//    }
