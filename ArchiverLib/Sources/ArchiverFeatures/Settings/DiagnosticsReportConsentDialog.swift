//
//  DiagnosticsReportConsentDialog.swift
//  ArchiverLib
//

import SwiftUI

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
