//
//  ScanTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import AVKit
import Combine
import Foundation
import os.log
import SwiftUI
import VisionKit

class ScanTabViewModel: ObservableObject {
    @Published var showDocumentScan: Bool = false
    @Published var progressValue: CGFloat = 0.0
    @Published var progressLabel: String = ""

    private var disposables = Set<AnyCancellable>()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    init() {
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
        notificationFeedback.prepare()
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizationStatus ==  .denied || authorizationStatus == .restricted {
            Log.send(.info, "Authorization status blocks camera access. Switch to preferences.")

            notificationFeedback.notificationOccurred(.warning)
            AlertViewModel.createAndPost(title: "Need Camera Access",
                                         message: "Camera access is required to scan documents.",
                                         primaryButton: .default(Text("Grant Access"),
                                                                 action: {
                                                                    guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
                                                                    UIApplication.shared.open(settingsAppURL, options: [:], completionHandler: nil)
                                         }),
                                         secondaryButton: .cancel())
        } else {

            Log.send(.info, "Start scanning a document.")
            showDocumentScan = true
            notificationFeedback.notificationOccurred(.success)

            // stop current image processing
            ImageConverter.shared.stopProcessing()
        }
    }

    func process(_ images: [UIImage]) {
        assert(!Thread.isMainThread, "This might take some time and should not be executed on the main thread.")

        ImageConverter.shared.startProcessing()

        // validate subscription
        guard testAppUsagePermitted() else { return }

        // save images in reversed order to fix the API output order
        do {
            try StorageHelper.save(images)
        } catch {
            assertionFailure("Could not save temp images with error:\n\(error.localizedDescription)")
            AlertViewModel.createAndPost(title: "Save failed!",
                                         message: error,
                                         primaryButtonTitle: "OK")
        }

        // notify ImageConverter
        triggerProcessing()

        // show processing indicator instantly
        updateProcessingIndicator(with: 0)
    }

    // MARK: - Helper Functions

    private func triggerProcessing() {
        do {
            try StorageHelper.triggerProcessing()
        } catch {
            AlertViewModel.createAndPost(title: "Attention",
                                         message: "Could not find iCloud Drive.",
                                         primaryButtonTitle: "OK")
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

                self.progressValue = min((CGFloat(completedDocuments) + CGFloat(documentProgress)) / CGFloat(totalDocuments), 1)
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
        if !isPermitted {
            AlertViewModel.createAndPost(title: "No Subscription",
                                         message: "No active subscription could be found. Your document will therefore not be saved.\nPlease support the app and subscribe.",
                                         primaryButton: .default(Text("Activate"), action: {
                                            // show the subscription view
                                            NotificationCenter.default.post(.showSubscriptionView)
                                         }),
                                         secondaryButton: .cancel({
                                            // cancel this alert and validate subscription state
                                            NotificationCenter.default.post(.subscriptionChanges)
                                         }))
        }

        return isPermitted
    }
}
