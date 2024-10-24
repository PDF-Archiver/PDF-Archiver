//
//  ArchiveStoreLoading.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.10.24.
//

import SwiftUI

struct ArchiveStoreLoading: ViewModifier {
    
    @State private var isLoading: Bool = true
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(isLoading ? 0 : 1)
            ProgressView {
                Text("Loading documents...")
            }
            .controlSize(.extraLarge)
            .opacity(isLoading ? 1 : 0)
        }
            .task {
                let isLoadingStream = await NewArchiveStore.shared.isLoadingStream
                for await isLoading in isLoadingStream {
                    self.isLoading = isLoading
                }
            }
    }
}
