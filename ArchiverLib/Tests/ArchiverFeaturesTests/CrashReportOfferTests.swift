import ComposableArchitecture
import Diagnostics
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct CrashReportOfferTests {
    let storedReport = StoredCrashReport(filename: "Crash-Report-1.json", data: Data("{}".utf8))
    let deliveredReport = StoredCrashReport(filename: "Crash-Report-2.json", data: Data("{\"crash\":2}".utf8))

    // MARK: - Launch

    @Test
    func aReportDeliveredDuringTheLaunchWindowJoinsTheStoredOnesInTheSameDialog() async throws {
        let clock = TestClock()
        let (incoming, incomingContinuation) = AsyncStream<StoredCrashReport>.makeStream()
        let store = TestStore(initialState: CrashReportOffer.State()) {
            CrashReportOffer()
        } withDependencies: { [storedReport] in
            $0.continuousClock = clock
            $0.crashReports.stored = { [storedReport] }
            $0.crashReports.storeIncoming = { incoming }
        }

        await store.send(.launched) {
            $0.isLaunchWindowOpen = true
        }
        await store.receive(\.reportsArrived) {
            $0.offered = [storedReport]
            $0.alert = CrashReportOffer.alert
        }

        await clock.advance(by: CrashReportOffer.launchWindow - .seconds(1))
        incomingContinuation.yield(deliveredReport)
        await store.receive(\.reportsArrived) {
            $0.offered = [storedReport, deliveredReport]
        }

        await clock.advance(by: .seconds(1))
        await store.receive(\.launchWindowClosed) {
            $0.isLaunchWindowOpen = false
        }
        incomingContinuation.finish()
        await store.finish()
    }

    @Test
    func aReportDeliveredAtLaunchIsOfferedRightAwayWithoutAStoredOne() async throws {
        let clock = TestClock()
        let store = TestStore(initialState: CrashReportOffer.State()) {
            CrashReportOffer()
        } withDependencies: { [deliveredReport] in
            $0.continuousClock = clock
            $0.crashReports.stored = { [] }
            $0.crashReports.storeIncoming = { AsyncStream { $0.yield(deliveredReport); $0.finish() } }
        }

        await store.send(.launched) {
            $0.isLaunchWindowOpen = true
        }
        await store.receive(\.reportsArrived) {
            $0.offered = [deliveredReport]
            $0.alert = CrashReportOffer.alert
        }
        await clock.run()
        await store.receive(\.launchWindowClosed) {
            $0.isLaunchWindowOpen = false
        }
    }

    @Test
    func aReportDeliveredAfterTheLaunchWindowWaitsForTheNextLaunch() async throws {
        let clock = TestClock()
        let (incoming, incomingContinuation) = AsyncStream<StoredCrashReport>.makeStream()
        let store = TestStore(initialState: CrashReportOffer.State()) {
            CrashReportOffer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.crashReports.stored = { [] }
            $0.crashReports.storeIncoming = { incoming }
        }

        await store.send(.launched) {
            $0.isLaunchWindowOpen = true
        }
        await clock.advance(by: CrashReportOffer.launchWindow)
        await store.receive(\.launchWindowClosed) {
            $0.isLaunchWindowOpen = false
        }

        incomingContinuation.yield(deliveredReport)
        // Already stored by `storeIncoming`, so the next launch offers it; no dialog mid-session.
        await store.receive(\.reportsArrived)
        incomingContinuation.finish()
        await store.finish()
    }

    // MARK: - Dialog

    @Test
    func sendingMailsTheReportsWithoutAskingAgainAndDiscardsThemOnceTheMailIsSent() async throws {
        let discarded = LockIsolated<[StoredCrashReport]>([])
        let store = TestStore(initialState: offering([storedReport])) {
            CrashReportOffer()
        } withDependencies: {
            $0.crashReports.discard = { reports in discarded.withValue { $0 += reports } }
            $0.diagnosticsMail.createReport = { DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data()) }
            $0.diagnosticsMail.send = { _ in true }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.alert(.presented(.sendTapped)))
        await store.receive(\.diagnosticsReportFlow.start)
        #expect(store.state.diagnosticsReportFlow.extraAttachments == [attachment(of: storedReport)])
        // The dialog was the consent, so the flow does not ask again.
        #expect(!store.state.diagnosticsReportFlow.isShowingConsent)

        #if os(iOS)
        await store.receive(\.diagnosticsReportFlow.reportCreated)
        // The compose sheet is up, the user has not sent the mail yet.
        #expect(discarded.value.isEmpty)
        await store.send(.diagnosticsReportFlow(.mailFinished(sent: true)))
        #endif
        await store.receive(\.diagnosticsReportFlow.delegate.mailSent)
        await store.finish()

        #expect(store.state.offered.isEmpty)
        #expect(store.state.inMail.isEmpty)
        #expect(discarded.value == [storedReport])
    }

    @Test
    func aMailThatWasNotSentKeepsTheReports() async throws {
        var state = CrashReportOffer.State()
        state.inMail = [storedReport]
        let store = TestStore(initialState: state) {
            CrashReportOffer()
        } withDependencies: {
            $0.crashReports.discard = { _ in Issue.record("A report was discarded before its mail was sent") }
        }

        await store.send(.diagnosticsReportFlow(.mailFinished(sent: false)))
        await store.finish()

        #expect(store.state.inMail == [storedReport])
    }

    @Test
    func notNowDiscardsTheReportsWithoutAMail() async throws {
        let discarded = LockIsolated<[StoredCrashReport]>([])
        let store = TestStore(initialState: offering([storedReport])) {
            CrashReportOffer()
        } withDependencies: {
            $0.crashReports.discard = { reports in discarded.withValue { $0 += reports } }
        }

        await store.send(.alert(.presented(.notNowTapped))) {
            $0.alert = nil
            $0.offered = []
        }
        await store.finish()

        #expect(discarded.value == [storedReport])
    }

    // MARK: - Helpers

    private func offering(_ reports: [StoredCrashReport]) -> CrashReportOffer.State {
        var state = CrashReportOffer.State()
        state.offered = reports
        state.alert = CrashReportOffer.alert
        return state
    }

    private func attachment(of report: StoredCrashReport) -> MailAttachment {
        MailAttachment(data: report.data, filename: report.filename, mimeType: "application/json")
    }
}
