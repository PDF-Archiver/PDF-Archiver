//
//  DropButton.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.05.24.
//

import SwiftUI
import OSLog

struct DropButton: View {
    enum State {
        case noDocument, targeted, processing, finished
    }

    let state: State
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            if state == .noDocument {
                Image(systemName: "doc.viewfinder")
                    .font(.title)
                    .foregroundColor(Color.paLightRed)
                    .padding(4)
            } else {
                ZStack {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.viewfinder")
                            .font(.title)
                            .foregroundColor(Color.paLightRed)
                        Text("Drop to import file")
                            .font(.caption)
                            .foregroundColor(Color.paDarkGray)
                    }
                    .padding(2)
                    .opacity(state == .targeted ? 1 : 0)

//                    ProgressView(value: DocumentProcessingService.shared.documentProgress)
//                        .progressViewStyle(.circular)
                    ProgressView()
                        .opacity(state == .processing ? 1 : 0)

                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                        .opacity(state == .finished ? 1 : 0)
                }

            }
        }
    }
}

#Preview("DropButton") {
    Group {
        DropButton(state: .noDocument, action: {})
        DropButton(state: .targeted, action: {})
        DropButton(state: .processing, action: {})
        DropButton(state: .finished, action: {})
    }
}
