//
//  ScanButtonViewModifier.swift
//
//
//  Created by Claude on 07.11.25.
//

import ComposableArchitecture
import OSLog
import Shared
import SwiftUI
import TipKit
import UniformTypeIdentifiers

struct ScanButtonViewModifier: ViewModifier {
    @Bindable var store: StoreOf<ScanButtonFeature>
    @Namespace var scanButtonNamespace

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                DropButton(state: store.dropHandler.documentProcessingState) { isLongPress in
                    store.send(.onScanButtonTapped(isLongPress: isLongPress))
                }
                #if os(macOS)
                .padding(.bottom, 24)
                .padding(.trailing, 40)
                #else
                .padding(.trailing, 10)
                #endif
                .opacity(store.showButton ? 1 : 0)
                .popoverTip((store.showButton && (store.currentTip as? ScanShareTip) != nil) ? store.currentTip : nil) { tipAction in
                    store.send(.onTipActionTapped(tipAction.id))
                }
                .tipImageSize(.init(width: 24, height: 24))
                .matchedTransitionSource(id: "scanButton", in: scanButtonNamespace)
            }
            #if !os(macOS)
            .sheet(isPresented: $store.isScanPresented) {
                DocumentCameraView(
                    isShown: $store.isScanPresented,
                    imageHandler: { images in
                        store.send(.onScanCompleted(images))
                    })
                    .edgesIgnoringSafeArea(.all)
                    .statusBar(hidden: true)
                    .navigationTransition(.zoom(sourceID: "scanButton", in: scanButtonNamespace))
            }
            .sheet(isPresented: $store.isShareSheetPresented) {
                if let url = store.documentToShare {
                    ShareSheet(title: url.lastPathComponent, url: url)
                }
            }
            #endif
            .onDrop(of: [.image, .pdf, .fileURL], delegate: TCADropDelegate(store: store))
            .fileImporter(isPresented: $store.dropHandler.isImporting, allowedContentTypes: [.pdf, .image]) { result in
                store.send(.onDropImportResult(result))
            }
            .onChange(of: store.dropHandler.isImporting) { oldValue, newValue in
                store.send(.onDropImportingChanged(old: oldValue, new: newValue))
            }
            .onOpenURL { url in
                store.send(.onOpenURL(url))
            }
    }
}

// MARK: - TCA Drop Delegate

private struct TCADropDelegate: DropDelegate {
    let store: StoreOf<ScanButtonFeature>

    func dropEntered(info: DropInfo) {
        store.send(.dropHandler(.dropEntered))
    }

    func dropExited(info: DropInfo) {
        store.send(.dropHandler(.dropExited))
    }

    func performDrop(info: DropInfo) -> Bool {
        let types: [UTType] = [.pdf, .image, .fileURL]
        guard info.hasItemsConforming(to: types) else { return false }
        let providers = info.itemProviders(for: types)

        store.send(.dropHandler(.performDrop(UncheckedSendableProviders(providers: providers))))
        return true
    }
}

// MARK: - View Extension

extension View {
    func scanButton(store: StoreOf<ScanButtonFeature>) -> some View {
        modifier(ScanButtonViewModifier(store: store))
    }
}
