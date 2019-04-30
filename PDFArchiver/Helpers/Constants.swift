//
//  Constants.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.04.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import UIKit.UIAlertController

enum Constants {

    static let untaggedFolderName = "untagged"

    static var archivePath: URL? = {
        guard let containerUrl = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        return containerUrl.appendingPathComponent("Documents")
    }()

    static var untaggedPath: URL? = {
        guard let archivePath = archivePath else { return nil }
        return archivePath.appendingPathComponent(untaggedFolderName)
    }()

    static let documentDescriptionPlaceholder = "PDF-ARCHIVER-TEMP-DESCRIPTION-"

    static let alertController: UIAlertController = {
        let alert = UIAlertController(title: NSLocalizedString("not-found.icloud-drive.title", comment: "Alert VC: Title"), message: NSLocalizedString("not-found.icloud-drive.text", comment: "Could not find a iCloud Drive Path."), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        return alert
    }()
}
