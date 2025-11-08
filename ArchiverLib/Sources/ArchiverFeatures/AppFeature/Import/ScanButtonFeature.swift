//
//  ScanButtonFeature.swift
//
//
//  Created by Claude on 07.11.25.
//

import ComposableArchitecture
import Foundation
import OSLog
import Shared
import SwiftUI
import TipKit
import UniformTypeIdentifiers

@Reducer
struct ScanButton {
    @ObservableState
    struct State: Equatable {
        var showButton: Bool = false
        var currentTip: (any Tip)?
        var isScanPresented = false
        var shouldShareAfterScan = false
        var isShareSheetPresented = false
        var documentToShare: URL?
        var dropHandler = PDFDropHandlerState()

        // Custom Equatable implementation excludes currentTip since Tip conformance
        // to Equatable is not available and comparing tips is not necessary for state equality
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.showButton == rhs.showButton &&
            lhs.isScanPresented == rhs.isScanPresented &&
            lhs.shouldShareAfterScan == rhs.shouldShareAfterScan &&
            lhs.isShareSheetPresented == rhs.isShareSheetPresented &&
            lhs.documentToShare == rhs.documentToShare &&
            lhs.dropHandler == rhs.dropHandler
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case dropHandler(PDFDropHandlerAction)
        case onScanButtonTapped(isLongPress: Bool)
        case onTipActionTapped(String)
        case onScanCompleted([PlatformImage])
        case onDocumentProcessed(URL?)
        case onDropImportResult(Result<URL, Error>)
        case onDropImportingChanged(old: Bool, new: Bool)
        case onOpenURL(URL)
    }

    @Dependency(\.documentProcessor) var documentProcessor
    @Dependency(\.feedbackGenerator) var feedbackGenerator

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .dropHandler(dropAction):
                return handleDropAction(&state, dropAction)

            case let .onScanButtonTapped(isLongPress):
                #if os(macOS)
                state.dropHandler.isImporting = true
                state.dropHandler.documentProcessingState = .processing
                #else
                state.shouldShareAfterScan = isLongPress
                state.isScanPresented = true
                #endif
                return .none

            case let .onTipActionTapped(actionId):
                #if os(macOS)
                state.dropHandler.isImporting = true
                state.dropHandler.documentProcessingState = .processing
                #else
                state.shouldShareAfterScan = (actionId == "scanAndShare")
                state.isScanPresented = true
                #endif
                return .none

            case let .onScanCompleted(images):
                return .run { send in
                    do {
                        await feedbackGenerator.notify(.success)
                        let processedUrl = await documentProcessor.handleImages(images)
                        await send(.onDocumentProcessed(processedUrl))
                        await AfterFirstImportTip.documentImported.donate()
                    } catch {
                        Logger.pdfDropHandler.errorAndAssert("Failed to handle scanned images", metadata: ["error": "\(error)"])
                        NotificationCenter.default.postAlert(error)
                    }
                }

            case let .onDocumentProcessed(url):
                if let url, state.shouldShareAfterScan {
                    state.documentToShare = url
                    state.isShareSheetPresented = true
                }
                state.shouldShareAfterScan = false
                return .none

            case let .onDropImportResult(result):
                return .run { send in
                    do {
                        let url = try result.get()
                        await send(.dropHandler(.handleImport(url)))
                    } catch {
                        Logger.pdfDropHandler.errorAndAssert("Failed to get imported url", metadata: ["error": "\(error)"])
                        NotificationCenter.default.postAlert(error)
                    }
                }

            case let .onDropImportingChanged(oldValue, newValue):
                guard oldValue,
                      !newValue,
                      state.dropHandler.documentProcessingState == .processing else {
                    return .none
                }
                return .send(.dropHandler(.abortImport))

            case let .onOpenURL(url):
                switch url {
                case DeepLink.scan.url:
                    state.isScanPresented = true

                case DeepLink.scanAndShare.url:
                    state.isScanPresented = true
                    state.shouldShareAfterScan = true

                default:
                    break
                }
                return .none
            }
        }
    }

    private func handleDropAction(_ state: inout State, _ action: PDFDropHandlerAction) -> Effect<Action> {
        switch action {
        case .startImport:
            state.dropHandler.documentProcessingState = .processing
            state.dropHandler.isImporting = true
            return .none

        case .abortImport:
            state.dropHandler.documentProcessingState = .noDocument
            state.dropHandler.isImporting = false
            return .none

        case let .handleImport(url):
            state.dropHandler.documentProcessingState = .processing
            return .run { [documentProcessor] send in
                do {
                    try await documentProcessor.handleFileImportUrl(url)
                    await send(.dropHandler(.finishDropHandling))
                } catch {
                    Logger.pdfDropHandler.errorAndAssert("Failed to handle import", metadata: ["error": "\(error)"])
                    await send(.dropHandler(.abortImport))
                }
            }

        case .finishDropHandling:
            guard state.dropHandler.documentProcessingState != .noDocument else {
                return .none
            }

            let wasProcessing = state.dropHandler.documentProcessingState == .processing
            state.dropHandler.documentProcessingState = wasProcessing ? .finished : .noDocument

            guard wasProcessing else { return .none }

            return .run { send in
                await documentProcessor.triggerFolderObservation()
                try? await Task.sleep(for: .seconds(2))
                await send(.dropHandler(.resetState))
            }

        case .resetState:
            state.dropHandler.documentProcessingState = .noDocument
            return .none

        case .dropEntered:
            state.dropHandler.documentProcessingState = .targeted
            return .none

        case .dropExited:
            guard state.dropHandler.documentProcessingState == .targeted else {
                return .none
            }
            state.dropHandler.documentProcessingState = .noDocument
            return .none

        case let .performDrop(wrappedProviders):
            state.dropHandler.documentProcessingState = .processing
            return .run { [documentProcessor] send in
                await documentProcessor.handleDropProviders(wrappedProviders.providers)
                await send(.dropHandler(.finishDropHandling))
            }
        }
    }
}

// MARK: - Supporting Types

struct PDFDropHandlerState: Equatable {
    var documentProcessingState: DropButton.ButtonState = .noDocument
    var isImporting = false
}

struct UncheckedSendableProviders: @unchecked Sendable, Equatable {
    let providers: [NSItemProvider]

    static func == (lhs: UncheckedSendableProviders, rhs: UncheckedSendableProviders) -> Bool {
        lhs.providers.count == rhs.providers.count
    }
}

enum PDFDropHandlerAction: Equatable {
    case startImport
    case abortImport
    case handleImport(URL)
    case finishDropHandling
    case resetState
    case dropEntered
    case dropExited
    case performDrop(UncheckedSendableProviders)
}
