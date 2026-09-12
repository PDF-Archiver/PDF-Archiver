//
//  MacBackgroundActivity.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

#if os(macOS)
import AppKit
import ArchiverDatabase
import ComposableArchitecture
import CoreGraphics
import Foundation
import IOKit.ps
import Shared

/// The macOS half of the index scheduler.
///
/// `BackgroundTasks` is unavailable to native Mac apps, so this is
/// `NSBackgroundActivityScheduler` plus the two conditions it has no flag for: external power and
/// an idle user. There is no launch-on-schedule on macOS, so it only runs while the app is alive.
actor MacBackgroundActivity {
    static let shared = MacBackgroundActivity()

    /// How long the user has to have kept their hands off before the index grows.
    private static let idleThreshold: TimeInterval = 120
    /// Documents per run, so a run ends soon after the user comes back.
    private static let budget = 25
    /// How often a running pass asks whether it should still be running.
    private static let deferPollInterval = 5.0

    private let scheduler = NSBackgroundActivityScheduler(identifier: "de.JulianKahnert.PDFArchiveViewer.index")
    private var observationTask: Task<Void, Never>?
    private var isAppActive = true

    @Dependency(\.archiveIndexer) private var archiveIndexer

    private init() {
        scheduler.repeats = true
        scheduler.interval = 15 * 60
        scheduler.qualityOfService = .background
    }

    func start() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                        await self?.setAppActive(true)
                    }
                }
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(named: NSApplication.didResignActiveNotification) {
                        await self?.setAppActive(false)
                    }
                }
            }
        }

        // Nothing inside may read `scheduler.shouldDefer`: the block returns the moment the pass is
        // spawned, and reading it afterwards raises `NSRangeException` and terminates the app.
        scheduler.schedule { completion in
            Task { [weak self = self] in
                guard let self,
                      await mayRunBackgroundWork(),
                      await PremiumEntitlement.isActive() else {
                    completion(.deferred)
                    return
                }

                let pass = Task {
                    await SearchIndexDownloads.requestNextBatch()
                    await self.archiveIndexer.indexPendingTexts(Self.budget)
                }
                // The user may come back long after the run started; the pass observes the
                // cancellation between documents.
                let watchdog = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(Self.deferPollInterval))
                        guard let self else { return }
                        guard await mayRunBackgroundWork() else {
                            pass.cancel()
                            return
                        }
                    }
                }
                await pass.value
                watchdog.cancel()

                completion(await mayRunBackgroundWork() ? .finished : .deferred)
            }
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        scheduler.invalidate()
    }

    /// `NSApplication.shared.isActive` is main-actor isolated, so the flag is cached from the two
    /// notifications instead of hopping inside the scheduler's block.
    private func mayRunBackgroundWork() -> Bool {
        !isAppActive
            && Self.isOnACPower()
            && Self.isCalm()
            && Self.idleSeconds() > Self.idleThreshold
    }

    private func setAppActive(_ isActive: Bool) {
        isAppActive = isActive
    }

    /// Both IOKit calls follow the Copy rule; the `CFString` bridges with Foundation imported.
    private static func isOnACPower() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPMACPowerKey
    }

    /// `ProcessInfo.ThermalState` is not `Comparable`, hence the switch.
    private static func isCalm() -> Bool {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal, .fair:
            return !ProcessInfo.processInfo.isLowPowerModeEnabled

        default:
            return false
        }
    }

    /// `kCGAnyInputEventType` is a C macro Swift does not import, and `.null` measures the time
    /// since the last *null* event, which is always large - the guard would never trigger.
    private static func idleSeconds() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
#endif
