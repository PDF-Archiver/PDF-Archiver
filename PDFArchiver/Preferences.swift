//
//  Preferences.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

struct Preferences {
    var archivePath: URL? {
        get {
            return UserDefaults.standard.url(forKey: "archivePath")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "archivePath")
        }
    }
}
