//
//  ArchiveStoreLoading.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.10.24.
//

import SwiftData
import SwiftUI

struct ArchiveStoreLoading: ViewModifier {
    @Query private var documents: [Document]
    @State private var isLoading: Bool = true

    func body(content: Content) -> some View {
        content
            // show loading spinner in toolbar if there are some documents, e.g. the persistet ones
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ProgressView()
                        .controlSize(.mini)
                        .opacity(isLoading && !documents.isEmpty ? 1 : 0)
                }
            }
            // show loading spinner across the entire screen if we are loading data and no previous documents were found, e.g. after a the DB is created
            .opacity(isLoading && documents.isEmpty ? 0 : 1)
            .overlay {
                ProgressView {
                    Text("Loading documents...")
                }
                .controlSize(.extraLarge)
                .opacity(isLoading && documents.isEmpty ? 1 : 0)
            }
            // handle loading state
            .task {
                let isLoadingStream = await ArchiveStore.shared.isLoadingStream
                for await isLoading in isLoadingStream {
                    self.isLoading = isLoading
                }
            }
    }
}
