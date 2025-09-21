//
//  DropButton.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.05.24.
//

import OSLog
import Shared
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
        if #available(iOS 26.0, macOS 26.0, *) {
            Button {
#if os(macOS)
                sensoryTrigger.toggle()
                action(false)
#endif
            } label: {
                ZStack {
                    Image(systemName: "doc.viewfinder")
                        .font(.title)
                        .foregroundColor(.white)
                        .opacity(![.processing, .finished].contains(state) ? 1 : 0)

                    ProgressView()
                        .tint(.white)
                        .opacity(state == .processing ? 1 : 0)

                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .opacity(state == .finished ? 1 : 0)
                }
                .symbolRenderingMode(.hierarchical)
            }
#if os(macOS)
            .frame(width: 40, height: 40)
            .buttonStyle(.glassProminent)
#else
            .padding(6)
            .glassEffect(.regular.tint(.accentColor).interactive(), in: Circle())
            .padding()
#endif

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
            .onChange(of: state) { _, newValue in
                guard newValue == .targeted else { return }
                shouldWiggle += 1
            }
            .sensoryFeedback(.success, trigger: sensoryTrigger)
        } else {
            legacyButton
                .padding(6)
        }
    }

    private var legacyButton: some View {
        Button {
            #if os(macOS)
            sensoryTrigger.toggle()
            action(false)
            #endif
        } label: {
            ZStack {
                Image(systemName: "doc.viewfinder")
                    .font(.title)
                    .foregroundColor(Color.paLightRedAsset)
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
        .background(Color.paPlaceholderGrayAsset, in: Capsule())
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
        .scaleEffect(state == .targeted ? 1.1 : 1)
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
