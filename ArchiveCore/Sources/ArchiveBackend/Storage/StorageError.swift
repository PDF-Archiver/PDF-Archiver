//
//  StorageHelper+Errors.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 11.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

enum StorageError: Error {
    case jpgConversion
    case noPathToSave
    case wrongExtension(String)
}
