//
//  ByteCountFormatter+Helper.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 04.10.25.
//

import Foundation

public extension Double {
    var formattedByteCount: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(self))
    }
}
