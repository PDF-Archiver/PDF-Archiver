//
//  DiagnosticsReportConsentDialog.swift
//  ArchiverLib
//

import ComposableArchitecture
import Shared
import SwiftUI
#if os(iOS)
import MessageUI
#endif

extension View {
    /// The consent dialog and, on iOS, the mail sheet of a `DiagnosticsReportFlow`.
    func diagnosticsReportFlow(store: StoreOf<DiagnosticsReportFlow>) -> some View {
        modifier(DiagnosticsReportFlowModifier(store: store))
    }
}

private struct DiagnosticsReportFlowModifier: ViewModifier {
    @Bindable var store: StoreOf<DiagnosticsReportFlow>

    func body(content: Content) -> some View {
        content
            .diagnosticsReportConsentDialog(
                isPresented: $store.isShowingConsent,
                onSendWithReport: { store.send(.sendWithReportTapped) },
                onSendWithoutReport: { store.send(.sendWithoutReportTapped) },
                onCancel: { store.send(.cancelTapped) }
            )
            #if os(iOS)
            .sheet(isPresented: $store.isShowingMailSheet) {
                if !MFMailComposeViewController.canSendMail() {
                    Text("Mail is not configured on this device", bundle: #bundle)
                        .padding()
                } else {
                    // Only presented once the consent decision is final, so the attachments are settled.
                    MailComposeView(
                        isShowing: $store.isShowingMailSheet,
                        recipient: Constants.mailRecipient,
                        subject: Constants.mailSubject,
                        attachments: store.mail.attachments
                    )
                }
            }
            #endif
    }
}

extension View {
    /// A `.confirmationDialog` on iOS and a native `.alert` on macOS, sharing the same title,
    /// message and three choices.
    func diagnosticsReportConsentDialog(
        isPresented: Binding<Bool>,
        onSendWithReport: @escaping () -> Void,
        onSendWithoutReport: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        confirmationDialog(
            Text("Request Support?", bundle: #bundle),
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            diagnosticsReportConsentButtons(onSendWithReport: onSendWithReport, onSendWithoutReport: onSendWithoutReport, onCancel: onCancel)
        } message: {
            Text("The report doesn't include file names or document contents — only information needed to diagnose the problem.", bundle: #bundle)
        }
        #else
        alert(
            Text("Request Support?", bundle: #bundle),
            isPresented: isPresented
        ) {
            diagnosticsReportConsentButtons(onSendWithReport: onSendWithReport, onSendWithoutReport: onSendWithoutReport, onCancel: onCancel)
        } message: {
            Text("The report doesn't include file names or document contents — only information needed to diagnose the problem.", bundle: #bundle)
        }
        #endif
    }
}

@MainActor
@ViewBuilder
private func diagnosticsReportConsentButtons(
    onSendWithReport: @escaping () -> Void,
    onSendWithoutReport: @escaping () -> Void,
    onCancel: @escaping () -> Void
) -> some View {
    Button {
        onSendWithReport()
    } label: {
        Text("With Report", bundle: #bundle)
    }
    Button {
        onSendWithoutReport()
    } label: {
        Text("Without Report", bundle: #bundle)
    }
    Button(role: .cancel) {
        onCancel()
    } label: {
        Text("Cancel", bundle: #bundle)
    }
}
