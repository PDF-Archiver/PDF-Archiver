//
//  MoreTableViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable cyclomatic_complexity function_body_length

import MessageUI
import UIKit

class MoreTableViewController: UITableViewController {

    // Section: preferences
    @IBOutlet private weak var pdfQualityCell: UITableViewCell!
    @IBOutlet private weak var showIntroCell: UITableViewCell!
    @IBOutlet private weak var showPermissionsCell: UITableViewCell!
    @IBOutlet private weak var resetAppCell: UITableViewCell!
    @IBOutlet private weak var manageSubscriptionCell: UITableViewCell!
    // Section: more information
    @IBOutlet private weak var aboutCell: UITableViewCell!
    @IBOutlet private weak var macOSAppCell: UITableViewCell!
    @IBOutlet private weak var privacyPolicyCell: UITableViewCell!
    @IBOutlet private weak var imprintCell: UITableViewCell!
    @IBOutlet private weak var supportCell: UITableViewCell!

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }

        let cell = tableView.cellForRow(at: indexPath)
        switch cell {
        case pdfQualityCell:
            return

        case showIntroCell:
            Log.info("More table view show: intro")
            let controller = IntroViewController()
            present(controller, animated: true, completion: nil)

        case showPermissionsCell:
            Log.info("More table view show: app permissions")
            guard let link = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
            UIApplication.shared.open(link)

        case resetAppCell:
            Log.info("More table view show: reset app")
            resetApp()

        case manageSubscriptionCell:
            Log.info("More table view show: manage subscription")
            guard let link = URL(string: "https://apps.apple.com/account/subscriptions") else { fatalError("Could not parse subscription url.") }
            UIApplication.shared.open(link)

        case aboutCell:
            Log.info("More table view show: About me")
            let controller = AboutMeViewController()
            navigationController?.pushViewController(controller, animated: true)

        case macOSAppCell:
            Log.info("More table view show: macOS App")
            guard let link = URL(string: "https://macos.pdf-archiver.io") else { fatalError("Could not parse macOS app url.") }
            UIApplication.shared.open(link)

        case privacyPolicyCell:
            Log.info("More table view show: privacy")
            guard let link = URL(string: NSLocalizedString("MoreTableViewController.privacyPolicyCell.url", comment: "")) else { fatalError("Could not parse termsOfUseCell url.") }
            UIApplication.shared.open(link)

        case imprintCell:
            Log.info("More table view show: imprint")
            guard let link = URL(string: NSLocalizedString("MoreTableViewController.imprintCell.url", comment: "")) else { fatalError("Could not parse privacyPolicyCell url.") }
            UIApplication.shared.open(link)

        case supportCell:
            Log.info("More table view show: support")
            if MFMailComposeViewController.canSendMail() {
                let mail = MFMailComposeViewController()
                mail.mailComposeDelegate = self
                mail.setToRecipients(["support@pdf-archiver.io"])
                mail.setSubject("PDF Archiver: iOS Support")

                present(mail, animated: true)
            } else {
                guard let url = URL(string: "https://pdf-archiver.io/faq") else { fatalError("Could not generate the FAQ url.") }
                UIApplication.shared.open(url)
            }

            func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
                controller.dismiss(animated: true)
            }

        default:
            fatalError("Could not find the table view cell \(cell?.description ?? "")!")
        }
    }

    private func resetApp() {
        // remove all temporary files
        if let tempImagePath = StorageHelper.Paths.tempImagePath {
            try? FileManager.default.removeItem(at: tempImagePath)
        } else {
            Log.error("Could not find tempImagePath.")
        }

        // remove all user defaults
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        } else {
            Log.error("Bundle Identifiert not found.")
        }

        let alert = UIAlertController(title: NSLocalizedString("MoreTableViewController.reset_app.title", comment: ""),
                                      message: NSLocalizedString("MoreTableViewController.reset_app.message", comment: ""),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension MoreTableViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        Log.info("Did finish MailComposeViewController.", extra: ["result": result, "error": error?.localizedDescription ?? ""])
        controller.dismiss(animated: true)
    }
}
