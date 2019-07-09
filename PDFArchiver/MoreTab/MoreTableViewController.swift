//
//  MoreTableViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit
import MessageUI

class MoreTableViewController: UITableViewController {

    // Section: preferences
    @IBOutlet private weak var showIntroCell: UITableViewCell!
    @IBOutlet private weak var showPermissionsCell: UITableViewCell!
    @IBOutlet private weak var resetAppCell: UITableViewCell!
    // Section: more information
    @IBOutlet private weak var macOSAppCell: UITableViewCell!
    @IBOutlet private weak var manageSubscriptionCell: UITableViewCell!
    @IBOutlet private weak var privacyPolicyCell: UITableViewCell!
    @IBOutlet private weak var imprintCell: UITableViewCell!
    @IBOutlet weak var supportCell: UITableViewCell!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // save the selected index for the next app start
        UserDefaults.standard.set(tabBarController?.selectedIndex ?? 2, forKey: Constants.UserDefaults.lastSelectedTabIndex.rawValue)
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }

        let cell = tableView.cellForRow(at: indexPath)
        switch cell {
        case showIntroCell:
            let controller = IntroViewController()
            present(controller, animated: true, completion: nil)

        case showPermissionsCell:
            guard let link = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
            UIApplication.shared.open(link)

        case resetAppCell:
            resetApp()

        case macOSAppCell:
            guard let link = URL(string: "https://macos.pdf-archiver.io") else { fatalError("Could not parse macOS app url.") }
            UIApplication.shared.open(link)

        case manageSubscriptionCell:
            guard let link = URL(string: "https://apps.apple.com/account/subscriptions") else { fatalError("Could not parse subscription url.") }
            UIApplication.shared.open(link)

        case privacyPolicyCell:
            guard let link = URL(string: NSLocalizedString("MoreTableViewController.privacyPolicyCell.url", comment: "")) else { fatalError("Could not parse termsOfUseCell url.") }
            UIApplication.shared.open(link)

        case imprintCell:
            guard let link = URL(string: NSLocalizedString("MoreTableViewController.imprintCell.url", comment: "")) else { fatalError("Could not parse privacyPolicyCell url.") }
            UIApplication.shared.open(link)

        case supportCell:
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
