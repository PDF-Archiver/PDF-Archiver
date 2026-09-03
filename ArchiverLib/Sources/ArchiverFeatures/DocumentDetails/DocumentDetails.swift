//
//  DocumentDetails.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
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
        @Shared var document: Document
        var documentInformationForm: DocumentInformationForm.State
        // initially always false to avoid UI glitches, e.g. not showing the inspector
        var showInspector = false
        var isRunningOcr = false
#if os(iOS)
        var shareDocument: ShareData?
#endif

        @SharedReader(.highlightDetectedDateEnabled)
        var highlightDetectedDateEnabled: Bool

        init(document: Shared<Document>) {
            self._document = document
            self.documentInformationForm = DocumentInformationForm.State(document: document.wrappedValue)
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
        case runOcrFinished(Bool)
#if os(iOS)
        case onShareButtonTapped
#endif
        case showDocumentInformationForm(DocumentInformationForm.Action)
        case updateShowInspector(Bool)

        enum Alert {
            case confirmDeleteButtonTapped
        }

        enum Delegate: Equatable {
            case deleteDocument(Document)
        }
    }

    @Dependency(\.archiveStore.startDownloadOf) var startDownloadOf
    @Dependency(\.documentProcessor) var documentProcessor
    var body: some ReducerOf<Self> {
        Scope(\.documentInformationForm, action: \.showDocumentInformationForm) {
            DocumentInformationForm()
        }

        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmDeleteButtonTapped)):
                return .send(.delegate(.deleteDocument(state.document)))

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
                return .run { [documentUrl = state.document.url] _ in
                    try await startDownloadOf(documentUrl)
                }

            case .runOcrFinished(let success):
                state.isRunningOcr = false
                guard !success else { return .none }
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
            store: Store(initialState: DocumentDetails.State(document: Shared(value: .mock(downloadStatus: 1)))) {
                DocumentDetails()
                    ._printChanges()
            }
        )
    }
}

#Preview("Loading", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationStack {
        DocumentDetailsView(
            store: Store(initialState: DocumentDetails.State(document: Shared(value: .mock(downloadStatus: 0.33)))) {
                DocumentDetails()
                    ._printChanges()
            }
        )
    }
}
