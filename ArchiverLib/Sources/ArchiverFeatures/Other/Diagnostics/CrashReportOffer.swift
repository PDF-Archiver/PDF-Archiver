//
//  CrashReportOffer.swift
//  ArchiverLib
//

import ComposableArchitecture
import SwiftUI

/// Offers the crash reports MetricKit delivered to support at launch, and discards them once the
/// user declined or the mail with them left the app.
@Reducer
struct CrashReportOffer {
    /// MetricKit delivers the previous run's crash within seconds of launch; a later delivery is
    /// only stored, so the dialog never interrupts the session.
    static let launchWindow: Duration = .seconds(10)

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        var isLaunchWindowOpen = false
        /// The reports the dialog asks about.
        var offered: [StoredCrashReport] = []
        /// The reports in the support mail, kept until the mail left the app.
        var inMail: [StoredCrashReport] = []
        var diagnosticsReportFlow = DiagnosticsReportFlow.State()
    }

    enum Action {
        case alert(PresentationAction<Alert>)
        case diagnosticsReportFlow(DiagnosticsReportFlow.Action)
        case launched
        case launchWindowClosed
        case reportsArrived([StoredCrashReport])

        enum Alert: Equatable {
            case sendTapped
            case notNowTapped
        }
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.crashReports) var crashReports

    var body: some ReducerOf<Self> {
        Scope(\.diagnosticsReportFlow, action: \.diagnosticsReportFlow) {
            DiagnosticsReportFlow()
        }
        Reduce { state, action in
            switch action {
            case .alert(.presented(.sendTapped)):
                let attachments = state.offered.map {
                    MailAttachment(data: $0.data, filename: $0.filename, mimeType: "application/json")
                }
                state.inMail += state.offered
                state.offered = []
                return .send(.diagnosticsReportFlow(.start(extraAttachments: attachments, askForConsent: false)))

            case .alert(.presented(.notNowTapped)):
                return discard(&state.offered)

            case .alert:
                return .none

            case .diagnosticsReportFlow(.delegate(.mailSent)):
                return discard(&state.inMail)

            case .diagnosticsReportFlow:
                return .none

            case .launched:
                state.isLaunchWindowOpen = true
                return .merge(
                    .run { send in
                        try await clock.sleep(for: Self.launchWindow)
                        await send(.launchWindowClosed)
                    },
                    .run(priority: .background) { send in
                        let stored = crashReports.stored()
                        if !stored.isEmpty {
                            await send(.reportsArrived(stored))
                        }
                        for await report in crashReports.storeIncoming() {
                            await send(.reportsArrived([report]))
                        }
                    }
                )

            case .launchWindowClosed:
                state.isLaunchWindowOpen = false
                return .none

            case .reportsArrived(let reports):
                guard state.isLaunchWindowOpen else { return .none }
                state.offered += reports
                state.alert = Self.alert
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func discard(_ reports: inout [StoredCrashReport]) -> Effect<Action> {
        let discarded = reports
        reports = []
        return .run { _ in crashReports.discard(discarded) }
    }

    static let alert = AlertState<Action.Alert> {
        TextState("Send Crash Report?", bundle: #bundle)
    } actions: {
        ButtonState(action: .sendTapped) {
            TextState("Send", bundle: #bundle)
        }
        ButtonState(role: .cancel, action: .notNowTapped) {
            TextState("Not Now", bundle: #bundle)
        }
    } message: {
        TextState("PDF Archiver quit unexpectedly last time. Send the crash report and a diagnostics report to support? You see the mail before it is sent.", bundle: #bundle)
    }
}

extension View {
    /// The crash report dialog and the support mail it starts.
    func crashReportOffer(store: StoreOf<CrashReportOffer>) -> some View {
        modifier(CrashReportOfferModifier(store: store))
    }
}

private struct CrashReportOfferModifier: ViewModifier {
    @Bindable var store: StoreOf<CrashReportOffer>

    func body(content: Content) -> some View {
        content
            .task { await store.send(.launched).finish() }
            .alert($store.scope(\.$alert, action: \.alert))
            .diagnosticsReportFlow(store: store.scope(\.diagnosticsReportFlow, action: \.diagnosticsReportFlow))
    }
}
