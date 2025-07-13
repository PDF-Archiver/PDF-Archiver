//
//  DocumentLoadingView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 25.10.24.
//

import SwiftUI

struct DocumentLoadingView: View {

    let filename: String
    let downloadStatus: Double

    var body: some View {
        VStack(spacing: 15) {
            Spacer()
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 55))
                .foregroundStyle(.secondary)
            Text("Downloading Document")
                .fontWeight(.semibold)
                .font(.title2)
            Text("The document will be downloaded to your device. Please wait.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
            ProgressView(filename, value: downloadStatus, total: 1)
                .progressViewStyle(.linear)
                .padding(40)
            Spacer()
        }
    }
}

#Preview {
    DocumentLoadingView(filename: "test.pdf",
                        downloadStatus: 0.33)
}
