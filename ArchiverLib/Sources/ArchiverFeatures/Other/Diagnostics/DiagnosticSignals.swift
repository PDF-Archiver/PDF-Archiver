import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Foundation
import Logging
import SQLiteData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// What surrounds the log lines while diagnostic logs are on: a heartbeat with memory, thermal and
/// power state, the app's lifecycle events, and every reported issue.
@MainActor
enum DiagnosticSignals: Log {
    private static var heartbeat: Task<Void, Never>?
    private static var observers: [any NSObjectProtocol] = []
    #if os(iOS)
    private static var wasMonitoringBattery = false
    #endif

    static func start() {
        guard heartbeat == nil else { return }
        IssueReporters.current.append(LoggingIssueReporter())
        #if os(iOS)
        wasMonitoringBattery = UIDevice.current.isBatteryMonitoringEnabled
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
        observers = lifecycleEvents.map { name, event in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    logLifecycleEvent(event)
                }
            }
        }
        heartbeat = Task {
            await beat()
        }
    }

    static func stop() {
        guard heartbeat != nil else { return }
        heartbeat?.cancel()
        heartbeat = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        IssueReporters.current.removeAll { $0 is LoggingIssueReporter }
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = wasMonitoringBattery
        #endif
    }

    static func applicationState() -> String {
        #if os(iOS)
        switch UIApplication.shared.applicationState {
        case .active:
            return "active"

        case .inactive:
            return "inactive"

        case .background:
            return "background"

        @unknown default:
            return "unknown"
        }
        #else
        return NSApplication.shared.isActive ? "active" : "inactive"
        #endif
    }

    // MARK: - Heartbeat

    private static func beat() async {
        var beatCount = 0
        while !Task.isCancelled {
            Self.log.info("Heartbeat", metadata: snapshot())
            // Every fifth beat: the counts read the database, and a minute is too short to see
            // the index move anyway.
            if beatCount % 5 == 0 {
                await logIndexStatus()
            }
            beatCount += 1
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return
            }
        }
    }

    private static func snapshot() -> Logger.Metadata {
        let processInfo = ProcessInfo.processInfo
        var metadata: Logger.Metadata = [
            "footprintMB": "\(physicalFootprint().map { "\($0 / 1_048_576)" } ?? "unknown")",
            "thermalState": "\(thermalStateName(processInfo.thermalState))",
            "lowPowerMode": "\(processInfo.isLowPowerModeEnabled)",
            "applicationState": "\(applicationState())"
        ]
        #if os(iOS)
        let batteryLevel = UIDevice.current.batteryLevel
        metadata["availableMemoryMB"] = "\(os_proc_available_memory() / 1_048_576)"
        metadata["batteryPercent"] = batteryLevel < 0 ? "unknown" : "\(Int((batteryLevel * 100).rounded()))"
        metadata["batteryState"] = "\(batteryStateName(UIDevice.current.batteryState))"
        #endif
        return metadata
    }

    private static func logIndexStatus() async {
        @Dependency(\.defaultDatabase) var database
        do {
            let status = try await database.read { db in
                try DocumentIndexState.StatusRequest().fetch(db)
            }
            Self.log.info("Index status", metadata: [
                "total": "\(status.total)",
                "indexed": "\(status.indexed)",
                "withoutText": "\(status.withoutText)",
                "failed": "\(status.failed)",
                "pending": "\(status.pending)",
                "notDownloaded": "\(status.notDownloaded)",
                "lastRun": "\(status.lastRun.map { $0.formatted(ArchiveLogFile.timestampStyle) } ?? "never")"
            ])
        } catch {
            Self.log.error("Could not read the index status", metadata: ["error": "\(LogRedact.describe(error))"])
        }
    }

    /// What jetsam compares against the process limit.
    private static func physicalFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integers in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), integers, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }

    private static func thermalStateName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "nominal"

        case .fair:
            return "fair"

        case .serious:
            return "serious"

        case .critical:
            return "critical"

        @unknown default:
            return "unknown"
        }
    }

    #if os(iOS)
    private static func batteryStateName(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown:
            return "unknown"

        case .unplugged:
            return "unplugged"

        case .charging:
            return "charging"

        case .full:
            return "full"

        @unknown default:
            return "unknown"
        }
    }
    #endif

    // MARK: - Lifecycle

    #if os(iOS)
    private static let lifecycleEvents: [(Notification.Name, String)] = [
        (UIApplication.didBecomeActiveNotification, "didBecomeActive"),
        (UIApplication.willResignActiveNotification, "willResignActive"),
        (UIApplication.didEnterBackgroundNotification, "didEnterBackground"),
        (UIApplication.willEnterForegroundNotification, "willEnterForeground"),
        (UIApplication.willTerminateNotification, "willTerminate"),
        (UIApplication.didReceiveMemoryWarningNotification, "didReceiveMemoryWarning"),
        (ProcessInfo.thermalStateDidChangeNotification, "thermalStateDidChange"),
        (.NSProcessInfoPowerStateDidChange, "powerStateDidChange"),
        (UIDevice.batteryStateDidChangeNotification, "batteryStateDidChange"),
        (UIDevice.batteryLevelDidChangeNotification, "batteryLevelDidChange")
    ]
    #else
    private static let lifecycleEvents: [(Notification.Name, String)] = [
        (NSApplication.didBecomeActiveNotification, "didBecomeActive"),
        (NSApplication.didResignActiveNotification, "didResignActive"),
        (NSApplication.didHideNotification, "didHide"),
        (NSApplication.didUnhideNotification, "didUnhide"),
        (NSApplication.willTerminateNotification, "willTerminate"),
        (ProcessInfo.thermalStateDidChangeNotification, "thermalStateDidChange"),
        (.NSProcessInfoPowerStateDidChange, "powerStateDidChange")
    ]
    #endif

    private static func logLifecycleEvent(_ event: String) {
        var metadata = snapshot()
        metadata["event"] = "\(event)"
        Self.log.notice("Lifecycle event", metadata: metadata)
    }
}

/// Routes `reportIssue` and `withErrorReporting` into the log - a release build drops them otherwise.
private struct LoggingIssueReporter: IssueReporter, Log {
    func reportIssue(_ message: @autoclosure () -> String?,
                     severity: IssueSeverity,
                     fileID: StaticString,
                     filePath: StaticString,
                     line: UInt,
                     column: UInt) {
        Self.log.error("Issue reported", metadata: [
            "issue": "\(LogRedact.redacted(message() ?? ""))",
            "severity": "\(severity)",
            "source": "\(fileID):\(line)"
        ])
    }

    func reportIssue(_ error: any Error,
                     _ message: @autoclosure () -> String?,
                     fileID: StaticString,
                     filePath: StaticString,
                     line: UInt,
                     column: UInt) {
        Self.log.error("Issue reported", metadata: [
            "error": "\(LogRedact.describe(error))",
            "issue": "\(LogRedact.redacted(message() ?? ""))",
            "source": "\(fileID):\(line)"
        ])
    }
}
