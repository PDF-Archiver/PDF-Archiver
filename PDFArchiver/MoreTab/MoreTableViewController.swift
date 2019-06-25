//
//  MoreTableViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

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
    }
}
