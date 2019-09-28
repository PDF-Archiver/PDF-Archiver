//
//  StorageHelper+Paths.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 11.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import UIKit.UIAlertController

extension StorageHelper {
    enum Paths {

        static let untaggedFolderName = "untagged"
        static let tempFolderName = "temp"

        static var archivePath: URL? = {
            guard let containerUrl = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                assertionFailure("Could not find default container identifier.")
                Log.send(.error, "Could not find default container identifier.")
                return nil
            }
            return containerUrl.appendingPathComponent("Documents")
        }()

        static var untaggedPath: URL? = {
            guard let archivePath = archivePath else { return nil }
            return archivePath.appendingPathComponent(untaggedFolderName)
        }()

        static var tempImagePath: URL? = {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let documentsDirectory = paths[0]
            return documentsDirectory.appendingPathComponent(tempFolderName)
        }()

        static let iCloudDriveAlertController: UIAlertController = {
            let alert = UIAlertController(title: NSLocalizedString("not-found.icloud-drive.title", comment: "Alert VC: Title"), message: NSLocalizedString("not-found.icloud-drive.text", comment: "Could not find a iCloud Drive Path."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            return alert
        }()
    }
}
