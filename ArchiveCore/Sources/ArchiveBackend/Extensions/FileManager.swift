//
//  FileManager.swift
//  
//
//  Created by Julian Kahnert on 17.11.20.
//

import Foundation

extension FileManager {
    var iCloudDriveURL: URL? {
        url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }

    var appContainerURL: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

}
