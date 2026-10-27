//
//  DiagnosticsReportFlow.swift
//  ArchiverLib
//

import ComposableArchitecture
import Diagnostics
import Foundation

/// A file the support mail carries next to the diagnostics report, e.g. a crash report.
struct MailAttachment: Equatable, Sendable {
    let data: Data
    let filename: String
    let mimeType: String
}

/// The support mail as it is handed to Mail: the diagnostics report, if the user agreed to send
/// it, and the attachments the feature that started the flow added.
struct DiagnosticsMail: Equatable, Sendable {
    let report: DiagnosticsReport?
    let extraAttachments: [MailAttachment]

    var attachments: [MailAttachment] {
        let reportAttachment = report.map {
            MailAttachment(data: $0.data, filename: $0.filename, mimeType: $0.mimeType.rawValue)
        }
        return (reportAttachment.map { [$0] } ?? []) + extraAttachments
    }
}

/// Consent, report creation and Mail delivery of a support mail with the diagnostics report.
/// Any feature embeds it, sends `.start` and attaches the view with `.diagnosticsReportFlow(store:)`.
@Reducer
struct DiagnosticsReportFlow {
    @ObservableState
    struct State: Equatable {
        var isShowingConsent = false
        var report: DiagnosticsReport?
        var isCreatingReport = false
        var didConfirmSending = false
        var extraAttachments: [MailAttachment] = []
        #if os(iOS)
        var isShowingMailSheet = false

        var mail: DiagnosticsMail {
            DiagnosticsMail(report: report, extraAttachments: extraAttachments)
        }
        #endif
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case cancelTapped
        case reportCreated(DiagnosticsReport)
        case sendWithReportTapped
        case sendWithoutReportTapped
        /// `askForConsent: false` is for a caller that already has the user's consent, so the
        /// mail opens as soon as the report is ready.
        case start(extraAttachments: [MailAttachment] = [], askForConsent: Bool = true)
    }

    private enum CancelID {
        case report
    }

    @Dependency(\.diagnosticsMail) var diagnosticsMail

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .cancelTapped:
                state.report = nil
                state.isCreatingReport = false
                state.didConfirmSending = false
                return .cancel(id: CancelID.report)

            case .reportCreated(let report):
                state.report = report
                state.isCreatingReport = false
                guard state.didConfirmSending else { return .none }
                return deliver(&state)

            case .sendWithReportTapped:
                state.didConfirmSending = true
                // If the report is still loading, `reportCreated` delivers it once it is ready.
                guard state.report != nil else { return .none }
                return deliver(&state)

            case .sendWithoutReportTapped:
                state.report = nil
                state.isCreatingReport = false
                state.didConfirmSending = false
                return .merge(.cancel(id: CancelID.report), deliver(&state))

            case let .start(extraAttachments, askForConsent):
                // Every start reports the state at that moment, never a report an earlier start produced.
                state.report = nil
                state.isCreatingReport = true
                state.extraAttachments = extraAttachments
                state.didConfirmSending = !askForConsent
                // The dialog goes up right away and the report keeps loading behind it,
                // so the button never looks dead while the user decides.
                state.isShowingConsent = askForConsent
                return .run { send in
                    await send(.reportCreated(diagnosticsMail.createReport()))
                }
                .cancellable(id: CancelID.report, cancelInFlight: true)
            }
        }
    }

    private func deliver(_ state: inout State) -> Effect<Action> {
        #if os(iOS)
        state.isShowingMailSheet = true
        return .none
        #else
        let mail = DiagnosticsMail(report: state.report, extraAttachments: state.extraAttachments)
        return .run { _ in await diagnosticsMail.send(mail) }
        #endif
    }
}
