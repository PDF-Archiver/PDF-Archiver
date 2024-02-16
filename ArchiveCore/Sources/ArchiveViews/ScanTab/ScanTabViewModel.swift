//
//  ScanTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable cyclomatic_complexity

import AVKit
import Combine
import Foundation
import PDFKit
import SwiftUI

#if os(macOS)
import AppKit.NSImage
private typealias UniversalImage = NSImage
#else
import UIKit.UIImage
private typealias UniversalImage = UIImage
#endif

// currently not working, because SPM does not know the APPCLIP compiler flag
#if APPCLIP
let shareDocumentAfterScanDefault = true
#else
let shareDocumentAfterScanDefault = false
#endif

public final class ScanTabViewModel: ObservableObject, DropDelegate, Log {
    @Published public var showDocumentScan = false
    @Published public var shareDocumentAfterScan: Bool = shareDocumentAfterScanDefault
    @Published public private(set) var progressValue: CGFloat = 0.0
    @Published public private(set) var progressLabel: String = " "

    private let imageConverter: ImageConverterAPI
    private let iapService: IAPServiceAPI

    private var lastProgressValue: CGFloat?
    private var disposables = Set<AnyCancellable>()

    public init(imageConverter: ImageConverterAPI, iapService: IAPServiceAPI) {
        self.imageConverter = imageConverter
        self.iapService = iapService

        // show the processing indicator, if documents are currently processed
        if imageConverter.totalDocumentCount.value != 0 {
            updateProcessingIndicator(with: 0)
        }

        // trigger processing (if temp images exist)
        triggerImageProcessing()

        NotificationCenter.default.publisher(for: .imageProcessingQueue)
            .sink { [weak self] notification in
                guard let self = self else { return }
                let documentProgress = notification.object as? Float
                self.updateProcessingIndicator(with: documentProgress)
            }
            .store(in: &disposables)
    }

    #if !os(macOS)
    public func startScanning() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorizationStatus {
            case .authorized:

                // show warning if app usage is not permitted
                testAppUsagePermitted()

                log.info("Start scanning a document.")
                showDocumentScan = true
                FeedbackGenerator.notify(.success)

                // stop current image processing
                imageConverter.stopProcessing()

            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        self.startScanning()
                    }
                }

            case .denied, .restricted:
                log.info("Authorization status blocks camera access. Switch to preferences.")

                FeedbackGenerator.notify(.warning)
                NotificationCenter.default.createAndPost(title: "Need Camera Access",
                                                         message: "Camera access is required to scan documents.",
                                                         primaryButton: .default(Text("Grant Access"),
                                                                                 action: {
                                                                                    guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
                                                                                    open(settingsAppURL)
                                                                                 }),
                                                         secondaryButton: .cancel())

            @unknown default:
                preconditionFailure("This authorization status is unknown.")
        }
    }
    #endif

    public func performDrop(info: DropInfo) -> Bool {
        let types: [UTType] = [.fileURL, .image, .pdf]
        let items = info.itemProviders(for: types)
        progressValue = 0.3
        progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + "30%"

        DispatchQueue.global(qos: .userInitiated).async {
            var error: Error?
            for item in items {
                let fileUrlType = UTType.fileURL.identifier
                if item.hasItemConformingToTypeIdentifier(fileUrlType) {
                    do {
                        let urls = try self.getUrls(of: item)
                        for url in urls {
                            try self.imageConverter.handle(url)
                        }
                        if !urls.isEmpty {
                            continue
                        }
                    } catch let getUrlError {
                        error = getUrlError
                    }
                }

                for uti in types where item.hasItemConformingToTypeIdentifier(uti.identifier) {
                    do {
                        guard let data = try item.syncLoadItem(forTypeIdentifier: uti) else { continue }

                        let url = PathConstants.tempPdfURL.appendingPathComponent("\(UUID().uuidString).pdf")
                        try data.write(to: url)
                        try self.imageConverter.handle(url)
                        continue
                    } catch let inputError {
                        self.log.errorAndAssert("Failed to handle image/pdf with type \(uti.identifier). Try next ...", metadata: ["error": "\(String(describing: error))"])
                        error = inputError
                    }
                }
            }
            if let error = error {
                NotificationCenter.default.postAlert(error)
            }

            // set progress/label to finished
            DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(500))) { [weak self] in
                guard let self else { return }
                self.progressValue = 1
                self.progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + "100%"

                // clear progress/label after some time
                DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(1))) { [weak self] in
                    guard let self,
                          self.progressValue == 1 else { return }

                    self.progressValue = 0
                    self.progressLabel = " "
                }
            }
        }

        return true
    }

    public func process(_ images: [CIImage]) {
        assert(!Thread.isMainThread, "This might take some time and should not be executed on the main thread.")

        // validate subscription
        guard testAppUsagePermitted() else { return }

        // show processing indicator instantly
        updateProcessingIndicator(with: 0)

        // save images in reversed order to fix the API output order
        do {
            try StorageHelper.save(images)
        } catch {
            assertionFailure("Could not save temp images with error:\n\(error)")
            NotificationCenter.default.postAlert(error)
        }

        // notify ImageConverter even if the image saving has failed
        triggerImageProcessing()
    }

    // MARK: - Helper Functions

    private func triggerImageProcessing() {
        do {
            try imageConverter.startProcessing()
        } catch {
            log.error("Failed to start processing.", metadata: ["error": "\(error)"])
            NotificationCenter.default.postAlert(error)
        }
    }

    private func updateProcessingIndicator(with documentProgress: Float?) {
        DispatchQueue.main.async {

            // we do not need a progress view, if the number of total documents is 0
            let totalDocuments = self.imageConverter.totalDocumentCount.value
            let tmpDocumentProgress = totalDocuments == 0 ? nil : documentProgress

            if let documentProgress = tmpDocumentProgress {

                let completedDocuments = totalDocuments - self.imageConverter.getOperationCount()
                let progressString = "\(min(completedDocuments + 1, totalDocuments))/\(totalDocuments) (\(Int(documentProgress * 100))%)"

                self.progressValue = min((CGFloat(completedDocuments) + CGFloat(documentProgress)) / CGFloat(totalDocuments), 1)
                self.progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + progressString
            } else {
                self.progressValue = 0
                self.progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + "0%"
            }
        }
    }

    @discardableResult
    private func testAppUsagePermitted() -> Bool {

        let isPermitted = iapService.appUsagePermitted

        // show subscription view controller, if no subscription was found
        if !isPermitted {
            DispatchQueue.main.async {
                NotificationCenter.default.createAndPost(title: "No Subscription",
                                                         message: "No active subscription could be found. Your document will therefore not be saved.\nPlease support the app and subscribe.",
                                                         primaryButton: .default(Text("Activate"), action: {
                                                            // show the subscription view
                                                            NotificationCenter.default.post(.showSubscriptionView)
                                                            self.showDocumentScan = false
                                                         }),
                                                         secondaryButton: .cancel(Text("OK")))
            }
        }

        return isPermitted
    }

    private func getUrls(of item: NSItemProvider) throws -> [URL] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[URL], Error>?
        _ = item.loadObject(ofClass: URL.self) { rawUrl, rawError in
            guard let url = rawUrl,
                  FileManager.default.directoryExists(at: url) else {
                result = .success([])
                semaphore.signal()
                return
            }

            do {
                if let error = rawError {
                    throw error
                }
                let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                result = .success(urls)
            } catch let inputError {
                self.log.errorAndAssert("Failed to handle file url input.", metadata: ["error": "\(String(describing: inputError))"])
                result = .failure(inputError)
                semaphore.signal()
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + .seconds(30))
        return try result?.get() ?? []
    }
}
