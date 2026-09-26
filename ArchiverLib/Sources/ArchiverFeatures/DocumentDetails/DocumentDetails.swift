//
//  DocumentDetails.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Logging
import Shared
import SQLiteData
import SwiftUI

@Reducer
struct DocumentDetails {

#if os(iOS)
    struct ShareData: Equatable, Identifiable {
        let id: UUID
        let title: String
        let url: URL
    }
#endif

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        /// Kept live so download progress and renames arrive; the parent clears the presentation
        /// when the id leaves its rows, so this never has to model "no document".
        @FetchOne var document: Document
        var documentInformationForm: DocumentInformationForm.State
        // initially always false to avoid UI glitches, e.g. not showing the inspector
        var showInspector = false
        var isRunningOcr = false
        /// How often the watchdog has restarted a download that never reported progress - only a
        /// conscious retry from the failure alert resets it, so the watchdog's own loop still ends.
        var downloadWatchdogRetryCount = 0
#if os(iOS)
        var shareDocument: ShareData?
#endif

        @SharedReader(.highlightDetectedDateEnabled)
        var highlightDetectedDateEnabled: Bool

        init(document: Document) {
            self._document = FetchOne(wrappedValue: document, Document.find(document.id))
            self.documentInformationForm = DocumentInformationForm.State(document: document)
        }
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case onDeleteDocumentButtonTapped
        case onEditButtonTapped
        case onRunOcrButtonTapped
        case onRemoteDocumentAppeared
        case onRemoteDocumentDownloadFailed
        case onRemoteDocumentDownloadWatchdogFired
        case runOcrFinished(Bool)
#if os(iOS)
        case onShareButtonTapped
#endif
        case showDocumentInformationForm(DocumentInformationForm.Action)
        case updateShowInspector(Bool)

        enum Alert {
            case confirmDeleteButtonTapped
            case retryDownloadButtonTapped
        }

        enum Delegate: Equatable {
            case deleteDocument(Document)
        }
    }

    @Dependency(\.archiveStore.reloadDocuments) var reloadDocuments
    @Dependency(\.archiveStore.startDownloadOf) var startDownloadOf
    @Dependency(\.continuousClock) var clock
    @Dependency(\.documentProcessor) var documentProcessor

    /// How long a download may sit at the same status before the watchdog restarts it - iCloud
    /// gives no signal of its own for "stalled" vs. "still queued".
    static let downloadWatchdogInterval: Duration = .seconds(20)
    static let maxDownloadWatchdogRetries = 3

    private enum CancelID {
        case downloadWatchdog
    }

    var body: some ReducerOf<Self> {
        Scope(\.documentInformationForm, action: \.showDocumentInformationForm) {
            DocumentInformationForm()
        }

        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmDeleteButtonTapped)):
                return .send(.delegate(.deleteDocument(state.document)))

            case .alert(.presented(.retryDownloadButtonTapped)):
                // A conscious retry gets a fresh watchdog budget; only the watchdog's own repeated
                // firing counts against it.
                state.downloadWatchdogRetryCount = 0
                return .send(.onRemoteDocumentAppeared)

            case .alert:
                return .none

            case .binding:
                return .none

            case .delegate:
                return .none

            case .onDeleteDocumentButtonTapped:
                state.alert = AlertState<Action.Alert> {
                    TextState("Delete document?", bundle: #bundle)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDeleteButtonTapped) {
                        TextState("Delete", bundle: #bundle)
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel", bundle: #bundle)
                    }
                } message: {
                    TextState("You are deleting the current document. Are you sure?", bundle: #bundle)
                }
                return .none

            case .onEditButtonTapped:
                if state.showInspector {
                    // reset the inspector state when it should disappear
                    state.documentInformationForm = DocumentInformationForm.State(
                        document: state.document)
                    state.showInspector = false
                } else {
#if os(iOS)
                    state.shareDocument = nil
#endif
                    state.showInspector = true
                }
                return .none

            case .onRunOcrButtonTapped:
                state.isRunningOcr = true
                return .run { [documentUrl = state.document.url] send in
                    await send(.runOcrFinished(await documentProcessor.runOcr(documentUrl)))
                }

            case .onRemoteDocumentAppeared:
                Logger.documentDetails.notice("Remote document appeared", metadata: [
                    "documentId": "\(state.document.id)",
                    "downloadStatus": "\(state.document.downloadStatus)"
                ])
                return .merge(
                    .run { [documentId = state.document.id, documentUrl = state.document.url] send in
                        do {
                            try await startDownloadOf(documentUrl)
                        } catch {
                            Logger.documentDetails.error("Failed to start document download", metadata: [
                                "documentId": "\(documentId)",
                                "error": "\(LogRedact.describe(error))"
                            ])
                            await send(.onRemoteDocumentDownloadFailed)
                        }
                    },
                    // `startDownloadOf` only requests the download - it reports neither progress nor
                    // a stall, so silence for this long is the only signal a hung download ever gives.
                    .run { send in
                        try? await clock.sleep(for: Self.downloadWatchdogInterval)
                        await send(.onRemoteDocumentDownloadWatchdogFired)
                    }
                    .cancellable(id: CancelID.downloadWatchdog, cancelInFlight: true)
                )

            case .onRemoteDocumentDownloadWatchdogFired:
                // The view already switched away from the loading screen once this is true; the
                // watchdog task itself is only torn down by the next `.onRemoteDocumentAppeared`.
                guard state.document.downloadStatus < 1 else { return .none }

                state.downloadWatchdogRetryCount += 1
                guard state.downloadWatchdogRetryCount <= Self.maxDownloadWatchdogRetries else {
                    return .send(.onRemoteDocumentDownloadFailed)
                }
                return .send(.onRemoteDocumentAppeared)

            case .onRemoteDocumentDownloadFailed:
                state.alert = AlertState<Action.Alert> {
                    TextState("Download failed", bundle: #bundle)
                } actions: {
                    ButtonState(action: .retryDownloadButtonTapped) {
                        TextState("Try Again", bundle: #bundle)
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel", bundle: #bundle)
                    }
                } message: {
                    TextState("The document could not be downloaded. Please check your connection and try again.", bundle: #bundle)
                }
                // The alert is already asking the user; a still-running watchdog must not restart
                // the download silently underneath it.
                return .cancel(id: CancelID.downloadWatchdog)

            case .runOcrFinished(let success):
                state.isRunningOcr = false
                guard !success else {
                    // The rewritten file has a new size and date; the rescan is what gets its
                    // fresh text layer indexed.
                    return .run { _ in
                        try await reloadDocuments()
                    }
                }
                state.alert = AlertState<Action.Alert> {
                    TextState("OCR failed", bundle: #bundle)
                } message: {
                    TextState("The text layer of this document could not be created. Please try again.", bundle: #bundle)
                }
                return .none

#if os(iOS)
            case .onShareButtonTapped:
                state.showInspector = false
                state.shareDocument = ShareData(
                    id: UUID(),
                    title: state.document.filename,
                    url: state.document.url)
                return .none
#endif

            case .showDocumentInformationForm:
                return .none

            case .updateShowInspector(let showInspector):
                state.showInspector = showInspector
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

#if os(macOS)
struct SaveDocumentAction: Equatable {
    let documentId: Document.ID
    let perform: () -> Void

    // closures are not Equatable; compare by document identity so the focused value
    // does not invalidate dependents on every unrelated update
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.documentId == rhs.documentId }
}

extension FocusedValues {
    @Entry var saveDocumentAction: SaveDocumentAction?
}

/// Publishes the macOS `File ▸ Save` menu command, wired to the front window's focused document.
public struct DocumentCommands: Commands {
    @FocusedValue(\.saveDocumentAction) private var saveDocumentAction

    public init() { }

    public var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button(String(localized: "Save", bundle: #bundle)) {
                saveDocumentAction?.perform()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(saveDocumentAction == nil)
        }
    }
}
#endif

struct DocumentDetailsView: View {
    @Bindable var store: StoreOf<DocumentDetails>

#if os(macOS)
    // Archive and Inbox each keep their own pushed document detail, while the
    // Save action is scene-wide - only the visible tab may publish it.
    @State private var isOnScreen = false
#endif

    #if os(macOS)
    /// The screenshot window is deliberately small, so the form takes just over the minimum and
    /// leaves the rest of the width to the document.
    private static var inspectorIdealWidth: CGFloat {
        #if DEBUG
        if ScreenshotCase.requested != nil {
            return 251
        }
        #endif
        return 400
    }
    #endif

    var body: some View {
        Group {
            if store.document.downloadStatus < 1 {
                DocumentLoadingView(filename: store.document.filename, downloadStatus: store.document.downloadStatus)
                    .task {
                        store.send(.onRemoteDocumentAppeared)
                    }
            } else {
                PDFCustomView(store.document.url, highlightDate: store.highlightDetectedDateEnabled ? store.documentInformationForm.document.date : nil)
                    .ignoresSafeArea(edges: [.bottom, .top])
                    .inspector(isPresented: $store.showInspector) {
                        DocumentInformationFormView(store: store.scope(\.documentInformationForm, action: \.showDocumentInformationForm))
#if os(iOS)
                            .presentationDetents([.medium, .large])
                            .presentationBackgroundInteraction(.enabled)
                            // hacky workaround to remove the transparency in the inspector
                            .presentationBackground(Color.paBackgroundAsset)
#else
                            .inspectorColumnWidth(min: 250, ideal: Self.inspectorIdealWidth, max: 600)
#endif
                    }
#if os(macOS)
                    .onAppear { isOnScreen = true }
                    .onDisappear { isOnScreen = false }
                    .focusedSceneValue(\.saveDocumentAction, isOnScreen && store.showInspector
                        ? SaveDocumentAction(documentId: store.document.id) {
                            store.send(.showDocumentInformationForm(.onSaveButtonTapped))
                        }
                        : nil)
#endif
            }
        }
        .alert($store.scope(\.$alert, action: \.alert))
#if os(iOS)
        .sheet(item: $store.shareDocument) { shareDocument in
            ShareSheet(title: shareDocument.title, url: shareDocument.url)
        }
#endif
        .toolbar {
            if #available(macOS 26.0, iOS 26.0, *) {
#if os(macOS)
                if store.document.isTagged {
                    ToolbarItem(placement: .accessoryBar(id: "tags")) {
                        // macOS Bug: the accessoryBar will trigger a high CPU usage
                        TagListView(
                            tags: store.document.tags.sorted(),
                            isEditable: false,
                            isMultiLine: false,
                            tapHandler: nil
                        )
                        .font(.caption)
                    }
                }
#endif

                ToolbarItem(id: "edit") {
                    Button {
                        store.send(.onEditButtonTapped)
                    } label: {
                        Label(String(localized: "Edit", bundle: #bundle), systemImage: "pencil")
                    }
                }

#if os(macOS)
                ToolbarItem(id: "showInFinder") {
                    Button(role: .none) {
                        NSWorkspace.shared.activateFileViewerSelecting([store.document.url])
                    } label: {
                        Label(String(localized: "Show in Finder", bundle: #bundle), systemImage: "folder")
                    }
                }
#endif

                ToolbarSpacer()

                if store.document.downloadStatus >= 1 {
                    ToolbarItem(id: "pdfInfo") {
                        pdfInfoView
                    }
                }

                ToolbarItem(id: "share") {
#if os(iOS)
                    Button(role: .none) {
                        store.send(.onShareButtonTapped)
                    } label: {
                        Label(String(localized: "Share", bundle: #bundle), systemImage: "square.and.arrow.up")
                    }
#else
                    // iOS Bug: when the inspector is active/shown, ShareLink will not trigger the share sheet.
                    // So we use the workaround with ShareSheet instead.
                    ShareLink(Text(store.document.filename), item: store.document.url)
#endif
                }

                ToolbarSpacer()

                ToolbarItem(id: "delete") {
                    Button(role: .destructive) {
                        store.send(.onDeleteDocumentButtonTapped)
                    } label: {
                        Label(String(localized: "Delete", bundle: #bundle), systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.glass(.identity))
                }
            } else {
                legacyToolbar
            }
        }
    }

    private var pdfInfoView: some View {
        PDFInfoView(documentURL: store.document.url,
                    isRunningOcr: store.isRunningOcr,
                    onRunOcr: { store.send(.onRunOcrButtonTapped) })
    }

    @ToolbarContentBuilder
    private var legacyToolbar: some ToolbarContent {
#if os(macOS)
        if store.document.isTagged {
            ToolbarItem(placement: .accessoryBar(id: "tags")) {
                // macOS Bug: the accessoryBar will trigger a high CPU usage
                TagListView(
                    tags: store.document.tags.sorted(),
                    isEditable: false,
                    isMultiLine: false,
                    tapHandler: nil
                )
                .font(.caption)
            }
        }
#endif

        ToolbarItemGroup(placement: .primaryAction) {
            // editButton
            Button {
                store.send(.onEditButtonTapped)
            } label: {
                Label(String(localized: "Edit", bundle: #bundle), systemImage: "pencil")
            }

            if store.document.downloadStatus >= 1 {
                pdfInfoView
            }

#if os(macOS)
            // showInFinderButton
            Button(role: .none) {
                NSWorkspace.shared.activateFileViewerSelecting([store.document.url])
            } label: {
                Label(String(localized: "Show in Finder", bundle: #bundle), systemImage: "folder")
            }
#endif

            // share button
#if os(iOS)
            Button(role: .none) {
                store.send(.onShareButtonTapped)
            } label: {
                Label(String(localized: "Share", bundle: #bundle), systemImage: "square.and.arrow.up")
            }
#else
            // iOS 18 Bug: when the inspector is active/shown, ShareLink will not trigger the share sheet.
            // So we use the workaround with ShareSheet instead.
            ShareLink(Text(store.document.filename), item: store.document.url)
#endif
            // deleteButton
            Button(role: .destructive) {
                store.send(.onDeleteDocumentButtonTapped)
            } label: {
                Label(String(localized: "Delete", bundle: #bundle), systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview("Document", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationStack {
        DocumentDetailsView(
            store: Store(initialState: DocumentDetails.State(document: .mock(downloadStatus: 1))) {
                DocumentDetails()
                    ._printChanges()
            }
        )
    }
}

#Preview("Loading", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationStack {
        DocumentDetailsView(
            store: Store(initialState: DocumentDetails.State(document: .mock(downloadStatus: 0.33))) {
                DocumentDetails()
                    ._printChanges()
            }
        )
    }
}
