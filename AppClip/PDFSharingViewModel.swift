//
//  PDFSharingViewModel.swift
//  AppClip
//
//  Created by Julian Kahnert on 23.10.20.
//

import Combine
import PDFKit
import SwiftUI

final class PDFSharingViewModel: ObservableObject, Equatable {
    static func == (lhs: PDFSharingViewModel, rhs: PDFSharingViewModel) -> Bool {
        lhs.pdfDocument == rhs.pdfDocument && lhs.sharingUrl == rhs.sharingUrl
    }

    @Published var error: Error?
    @Published var pdfDocument: PDFDocument?
    @Published var sharingUrl: URL?

    private var disposables = Set<AnyCancellable>()

    func shareDocument() {
        withAnimation {
            self.sharingUrl = self.pdfDocument?.documentURL
        }
    }

    func delete() {
        withAnimation {
            self.pdfDocument = nil
            guard let sharingUrl = self.sharingUrl else { return }
            do {
                try FileManager.default.removeItem(at: sharingUrl)
            } catch {
                NotificationCenter.default.postAlert(error)
            }
        }
    }
}
