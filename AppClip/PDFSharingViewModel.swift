//
//  PDFSharingViewModel.swift
//  AppClip
//
//  Created by Julian Kahnert on 23.10.20.
//

import ArchiveSharedConstants
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

    init() {
        NotificationCenter.default.publisher(for: .foundProcessedDocument)
            .compactMap { _ -> URL? in
                let fileManager = FileManager.default
                return try? fileManager.contentsOfDirectory(at: PathConstants.tempPdfURL, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
                    .max { url1, url2 in
                        guard let date1 = (try? fileManager.attributesOfItem(atPath: url1.path))?[.creationDate] as? Date,
                              let date2 = (try? fileManager.attributesOfItem(atPath: url2.path))?[.creationDate] as? Date else { return false }
                        return date1 < date2
                    }
            }
            .compactMap(PDFDocument.init)
            .assign(to: &$pdfDocument)
    }

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
