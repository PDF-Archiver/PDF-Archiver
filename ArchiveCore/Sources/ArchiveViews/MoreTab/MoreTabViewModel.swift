//
//  MoreTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_unwrapping

import Combine
#if canImport(MessageUI)
import MessageUI
#endif
import SwiftUI

final public class MoreTabViewModel: ObservableObject, Log {

    static let mailRecipients = ["support@pdf-archiver.io"]
    static let mailSubject = "PDF Archiver: iOS Support"

    let qualities: [String]  = ["100% - Lossless 🤯", "75% - Good 👌 (Default)", "50% - Normal 👍", "25% - Small 💾"]
    let storageTypes: [String]  = StorageType.allCases.map(\.title).map { "\($0)" }
    @Published var error: Error?
    @Published var selectedQualityIndex = UserDefaults.PDFQuality.toIndex(UserDefaults.appGroup.pdfQuality) ?? UserDefaults.PDFQuality.defaultQualityIndex
    @Published var selectedArchiveIndex = StorageType.toIndex(StorageType.getCurrent())!

    @Published var isShowingMailView: Bool = false
    #if canImport(MessageUI)
    @Published var result: Result<MFMailComposeResult, Error>?
    #endif
    @Published var subscriptionStatus: LocalizedStringKey = "Inactive ❌"

    private let iapService: IAPServiceAPI
    private var disposables = Set<AnyCancellable>()

    public init(iapService: IAPServiceAPI) {
        self.iapService = iapService
        $selectedQualityIndex
            .sink { selectedQuality in
                UserDefaults.appGroup.pdfQuality = UserDefaults.PDFQuality.allCases[selectedQuality]
            }
            .store(in: &disposables)

        iapService.appUsagePermittedPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { appUsagePermitted in
                self.subscriptionStatus = appUsagePermitted ? "Active ✅" : "Inactive ❌"
            }
            .store(in: &disposables)
    }

    func showIntro() {
        log.info("More table view show: intro")
        NotificationCenter.default.post(name: .introChanges, object: true)
    }

    func showPermissions() {
        log.info("More table view show: app permissions")
        #if os(macOS)
        // TODO: handle settings
        #else
        guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
        open(settingsAppURL)
        #endif
    }

    func resetApp() {
        log.info("More table view show: reset app")
        // remove all temporary files
        try? FileManager.default.removeItem(at: PathConstants.tempImageURL)

        // remove all user defaults
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.appGroup.removePersistentDomain(forName: bundleIdentifier)
        } else {
            log.error("Bundle Identifier not found.")
        }

        DispatchQueue.main.async {
            self.error = AlertDataModel.createAndPost(title: "Reset App", message: "Please restart the app to complete the reset.", primaryButtonTitle: "OK")
        }
    }

    var manageSubscriptionUrl: URL {
        URL(string: "https://apps.apple.com/account/subscriptions")!
    }

    var macOSAppUrl: URL {
        URL(string: "https://macos.pdf-archiver.io")!
    }

    func showSupport() {
        log.info("More table view show: support")
        #if os(macOS)
        sendDiagnosticsReport()
        #else
        if MFMailComposeViewController.canSendMail() {
            isShowingMailView = true
        } else {
            guard let url = URL(string: "https://pdf-archiver.io/faq") else { preconditionFailure("Could not generate the FAQ url.") }
            open(url)
        }
        #endif
    }
}

#if os(macOS)
import AppKit
import Diagnostics

extension MoreTabViewModel {
    func sendDiagnosticsReport() {
        // add a diagnostics report
        var reporters = DiagnosticsReporter.DefaultReporter.allReporters
        reporters.insert(CustomDiagnosticsReporter.self, at: 1)
        let report = DiagnosticsReporter.create(using: reporters)

        guard let service = NSSharingService(named: .composeEmail) else {
            log.errorAndAssert("Failed to get sharing service.")

            guard let url = URL(string: "https://pdf-archiver.io/faq") else { preconditionFailure("Could not generate the FAQ url.") }
            open(url)
            return
        }
        service.recipients = Self.mailRecipients
        service.subject = Self.mailSubject

        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Diagnostics-Report.html")

        // remove previous report
        try? FileManager.default.removeItem(at: url)

        do {
            try report.data.write(to: url)
        } catch {
            preconditionFailure("Failed with error: \(error)")
        }

        service.perform(withItems: [url])
    }
}
#endif
