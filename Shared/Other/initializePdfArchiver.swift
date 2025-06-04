//
//  init.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 18.06.24.
//

import Foundation

func initializePdfArchiver() {
    Task(priority: .userInitiated) {
        do {
            try await ArchiveStore.shared.reloadArchiveDocuments()
        } catch {
            NotificationCenter.default.postAlert(error)
        }
    }
}
