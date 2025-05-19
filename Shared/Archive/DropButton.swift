//
//  DropButton.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.05.24.
//

import OSLog
import SwiftUI

struct DropButton: View {
    enum ButtonState {
        case noDocument, targeted, processing, finished
    }

    let state: ButtonState
    let action: (_ isLongPress: Bool) -> Void
    
    @State private var sensoryTrigger = false
    
    var body: some View {
        Button {
            #if os(macOS)
            sensoryTrigger.toggle()
            action(false)
            #endif
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
        #if !os(macOS)
        .simultaneousGesture(
            LongPressGesture()
                .onEnded { _ in
                    sensoryTrigger.toggle()
                    let isLongPress = true
                    action(isLongPress)
                }
        )
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    sensoryTrigger.toggle()
                    let isLongPress = false
                    action(isLongPress)
                }
        )
        #endif
//        .popoverTip(ArchiverTips.dropButton) { tipAction in
//            sensoryTrigger.toggle()
//            if tipAction.id == "scan" {
//                action(false)
//            } else if tipAction.id == "scanAndShare" {
//                action(true)
//            }
//        }
        .sensoryFeedback(.success, trigger: sensoryTrigger)
    }
}

#Preview("DropButton") {
    Group {
        DropButton(state: .noDocument, action: { _ in })
        DropButton(state: .targeted, action: { _ in })
        DropButton(state: .processing, action: { _ in })
        DropButton(state: .finished, action: { _ in })
    }
}
