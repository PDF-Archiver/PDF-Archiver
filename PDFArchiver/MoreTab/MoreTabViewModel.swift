//
//  MoreTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Combine
import MessageUI
import SwiftUI

class MoreTabViewModel: ObservableObject {

    static let mailRecipients = ["support@pdf-archiver.io"]
    static let mailSubject = "PDF Archiver: iOS Support"

    @Published var qualities: [LocalizedStringKey]  = ["100% - Lossless 🤯", "75% - Good 👌 (Default)", "50% - Normal 👍", "25% - Small 💾"]
    @Published var selectedQualityIndex = UserDefaults.PDFQuality.toIndex(UserDefaults.standard.pdfQuality)

    @Published var isShowingMailView: Bool = false
    @Published var result: Result<MFMailComposeResult, Error>?
    var subscriptionStatus: LocalizedStringKey {
        IAP.service.appUsagePermitted() ? "Active ✅" : "Inactive ❌"
    }

    private var disposables = Set<AnyCancellable>()

    init() {
        $selectedQualityIndex
            .sink { selectedQuality in
                UserDefaults.standard.pdfQuality = UserDefaults.PDFQuality.allCases[selectedQuality]
            }
            .store(in: &disposables)
    }

    func showIntro() {
        Log.send(.info, "More table view show: intro")
        NotificationCenter.default.post(name: .introChanges, object: true)
    }

    func showPermissions() {
        Log.send(.info, "More table view show: app permissions")
        guard let link = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
        UIApplication.shared.open(link)
    }

    func resetApp() {
        Log.send(.info, "More table view show: reset app")
        // remove all temporary files
        if let tempImagePath = StorageHelper.Paths.tempImagePath {
            try? FileManager.default.removeItem(at: tempImagePath)
        } else {
            Log.send(.error, "Could not find tempImagePath.")
        }

        // remove all user defaults
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        } else {
            Log.send(.error, "Bundle Identifier not found.")
        }

        AlertViewModel.createAndPost(title: "Reset App", message: "Please restart the app to complete the reset.", primaryButtonTitle: "OK")
    }

    func showManageSubscription() {
        Log.send(.info, "More table view show: manage subscription")
        guard let link = URL(string: "https://apps.apple.com/account/subscriptions") else { fatalError("Could not parse subscription url.") }
        UIApplication.shared.open(link)
    }

    func showMacOSApp() {
        Log.send(.info, "More table view show: macOS App")
        guard let link = URL(string: "https://macos.pdf-archiver.io") else { fatalError("Could not parse macOS app url.") }
        UIApplication.shared.open(link)
    }

    func showPrivacyPolicy() {
        Log.send(.info, "More table view show: privacy")
        guard let link = URL(string: NSLocalizedString("MoreTableViewController.privacyPolicyCell.url", comment: "")) else { fatalError("Could not parse termsOfUseCell url.") }
        UIApplication.shared.open(link)
    }

    func showImprintCell() {
        Log.send(.info, "More table view show: imprint")
        guard let link = URL(string: NSLocalizedString("MoreTableViewController.imprintCell.url", comment: "")) else { fatalError("Could not parse privacyPolicyCell url.") }
        UIApplication.shared.open(link)
    }

    func showSupport() {
        Log.send(.info, "More table view show: support")
        if MFMailComposeViewController.canSendMail() {
            isShowingMailView = true
        } else {
            guard let url = URL(string: "https://pdf-archiver.io/faq") else { fatalError("Could not generate the FAQ url.") }
            UIApplication.shared.open(url)
        }
    }
}
