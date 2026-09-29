//
//  DropButton.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.05.24.
//

import Shared
import SwiftUI

/// What lifting the finger off the held scan button does, decided by how far it was slid.
enum ScanButtonRelease: Equatable {
    case scan, scanAndShare, cancel

    /// Center of the share bubble, relative to the center of the scan button.
    static let shareTargetOffset = CGSize(width: 0, height: -76)

    static func isOverShareTarget(_ translation: CGSize) -> Bool {
        hypot(translation.width - shareTargetOffset.width, translation.height - shareTargetOffset.height) < 36
    }

    init(translation: CGSize) {
        if Self.isOverShareTarget(translation) {
            self = .scanAndShare
        } else if hypot(translation.width, translation.height) < 32 {
            self = .scan
        } else {
            self = .cancel
        }
    }
}

struct DropButton: View {
    enum ButtonState {
        case noDocument, targeted, processing, finished
    }

    let state: ButtonState
    let action: (_ shouldShare: Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace

    @State private var sensoryTrigger = false
    // chandes of this value wiggles the Image
    @State private var shouldWiggle = 0
    // `nil` while the button is not held; SwiftUI resets it when the gesture ends or gets cancelled.
    @GestureState private var holdTranslation: CGSize?

    private var isHolding: Bool {
        holdTranslation != nil
    }

    private var isOverShareTarget: Bool {
        holdTranslation.map(ScanButtonRelease.isOverShareTarget) ?? false
    }

    private var buttonOffset: CGSize {
        guard let holdTranslation else { return .zero }
        return isOverShareTarget ? ScanButtonRelease.shareTargetOffset : holdTranslation
    }

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer {
                Button {
                    release(.scan)
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
                .frame(width: 50, height: 50)
                .buttonStyle(.glassProminent)
#else
                .padding(6)
                .glassEffect(.regular.tint(.paRedAsset).interactive(), in: Circle())
                .glassEffectID("scan", in: glassNamespace)
                .highPriorityGesture(scanGesture)
                .offset(buttonOffset)
                .overlay {
                    if isHolding {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(12)
                            .glassEffect(.regular.tint(isOverShareTarget ? .paRedAsset : .gray), in: Circle())
                            .glassEffectID("share", in: glassNamespace)
                            .glassEffectTransition(.matchedGeometry)
                            .scaleEffect(isOverShareTarget ? 1.15 : 1)
                            .offset(ScanButtonRelease.shareTargetOffset)
                    }
                }
#endif
            }
#if !os(macOS)
            .padding()
            .modifier(HoldToShareFeedback(isHolding: isHolding, isOverShareTarget: isOverShareTarget, reduceMotion: reduceMotion))
            .accessibilityAction(named: Text("Scan & Share", bundle: #bundle)) { release(.scanAndShare) }
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
            release(.scan)
        } label: {
            ZStack {
                Image(systemName: "doc.viewfinder")
                    .font(.title)
                    .foregroundColor(Color.paRedAsset)
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
        .highPriorityGesture(scanGesture)
        .offset(buttonOffset)
        .overlay {
            if isHolding {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(isOverShareTarget ? .white : Color.paRedAsset)
                    .padding(12)
                    .background(isOverShareTarget ? Color.paRedAsset : Color.paPlaceholderGrayAsset, in: Circle())
                    .scaleEffect(isOverShareTarget ? 1.15 : 1)
                    .offset(ScanButtonRelease.shareTargetOffset)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .modifier(HoldToShareFeedback(isHolding: isHolding, isOverShareTarget: isOverShareTarget, reduceMotion: reduceMotion))
        .accessibilityAction(named: Text("Scan & Share", bundle: #bundle)) { release(.scanAndShare) }
        #endif
        .onChange(of: state) { _, newValue in
            guard newValue == .targeted else { return }
            shouldWiggle += 1
        }
        .sensoryFeedback(.success, trigger: sensoryTrigger)
        .scaleEffect(state == .targeted && !reduceMotion ? 1.1 : 1)
        .animation(.snappy, value: state)
    }

    // A quick tap fails the long press, so only then does the tap get its turn.
    private var scanGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.15)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($holdTranslation) { value, holdTranslation, _ in
                guard case .second(true, let drag) = value else { return }
                holdTranslation = drag?.translation ?? .zero
            }
            .onEnded { value in
                guard case .second(true, let drag) = value else { return }
                release(ScanButtonRelease(translation: drag?.translation ?? .zero))
            }
            .exclusively(before: TapGesture().onEnded { release(.scan) })
    }

    private func release(_ outcome: ScanButtonRelease) {
        switch outcome {
        case .scan:
            sensoryTrigger.toggle()
            action(false)

        case .scanAndShare:
            sensoryTrigger.toggle()
            action(true)

        case .cancel:
            break
        }
    }
}

/// Springs and haptics for the hold-to-share bubble; following the finger itself stays unanimated.
private struct HoldToShareFeedback: ViewModifier {
    let isHolding: Bool
    let isOverShareTarget: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : .bouncy, value: isHolding)
            .animation(reduceMotion ? nil : .snappy, value: isOverShareTarget)
            .sensoryFeedback(.impact(weight: .light), trigger: isHolding) { _, isHolding in isHolding }
            .sensoryFeedback(.selection, trigger: isOverShareTarget)
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
