import ComposableArchitecture
import Diagnostics
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct DiagnosticsReportFlowTests {
    let report = DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data("report".utf8))
    let crashReport = MailAttachment(data: Data("{}".utf8), filename: "Crash-Report.json", mimeType: "application/json")

    @Test
    func anExtraAttachmentReachesTheDeliveryNextToTheReport() async throws {
        let deliveredMails = LockIsolated<[DiagnosticsMail]>([])
        let store = TestStore(initialState: DiagnosticsReportFlow.State()) {
            DiagnosticsReportFlow()
        } withDependencies: { [report] in
            $0.diagnosticsMail.createReport = { report }
            $0.diagnosticsMail.send = { mail in deliveredMails.withValue { $0.append(mail) } }
        }

        await store.send(.start(extraAttachments: [crashReport], askForConsent: false)) {
            $0.isCreatingReport = true
            $0.didConfirmSending = true
            $0.extraAttachments = [crashReport]
        }
        await store.receive(\.reportCreated) {
            $0.report = report
            $0.isCreatingReport = false
            #if os(iOS)
            $0.isShowingMailSheet = true
            #endif
        }
        await store.finish()

        #if os(iOS)
        #expect(store.state.mail == DiagnosticsMail(report: report, extraAttachments: [crashReport]))
        #else
        #expect(deliveredMails.value == [DiagnosticsMail(report: report, extraAttachments: [crashReport])])
        #endif
    }

    @Test
    func startingAsksForConsentAndKeepsLoadingTheReportBehindTheDialog() async throws {
        let store = TestStore(initialState: DiagnosticsReportFlow.State(report: report)) {
            DiagnosticsReportFlow()
        } withDependencies: { [report] in
            $0.diagnosticsMail.createReport = { report }
        }

        await store.send(.start()) {
            $0.report = nil
            $0.isCreatingReport = true
            $0.isShowingConsent = true
        }
        await store.receive(\.reportCreated) {
            $0.report = report
            $0.isCreatingReport = false
        }
    }
}
