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
    // chandes of this value wiggles the Image
    @State private var shouldWiggle = 0

    var body: some View {
        Button {
            #if os(macOS)
            sensoryTrigger.toggle()
            action(false)
            #endif
        } label: {
            ZStack {
                Image(systemName: "doc.viewfinder")
                    .font(.title)
                    .foregroundColor(Color.paLightRed)
                    .symbolEffect(.pulse.byLayer, options: .speed(2), value: shouldWiggle)
                    .opacity(![.processing, .finished].contains(state) ? 1 : 0)

                ProgressView()
                    .opacity(state == .processing ? 1 : 0)

                Image(systemName: "checkmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                    .opacity(state == .finished ? 1 : 0)
            }
            .symbolRenderingMode(.hierarchical)

            #if os(macOS)
            .frame(width: 40, height: 40)
            #else
            .frame(width: 60, height: 60)
            #endif
        }
        #if !os(macOS)
        .background(Color.paPlaceholderGray, in: Capsule())
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
        .onChange(of: state) { _, newValue in
            guard newValue == .targeted else { return }
            shouldWiggle += 1
        }
        .sensoryFeedback(.success, trigger: sensoryTrigger)
        .scaleEffect(state == .targeted ? 1.5 : 1)
        .animation(.snappy, value: state)
    }
}

#Preview("DropButton") {
    Group {
        DropButton(state: .noDocument, action: { _ in })
        DropButton(state: .targeted, action: { _ in })
        DropButton(state: .processing, action: { _ in })
        DropButton(state: .finished, action: { _ in })
    }
    .padding()
}
