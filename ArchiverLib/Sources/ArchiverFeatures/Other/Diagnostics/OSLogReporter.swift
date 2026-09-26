import ArchiverModels
import Diagnostics
import Foundation
import OSLog

/// Adds the running session's own-process OSLog entries (`.info` and above) as a diagnostics
/// chapter. `LogRedact` at the call sites is what makes these entries safe to include, since
/// `OSLogHandler` writes every message as one `privacy: .public` string.
struct OSLogReporter: DiagnosticsReporting {
    // `report()` is `async` to satisfy `DiagnosticsReporting`; reading OSLogStore is synchronous.
    // swiftlint:disable:next async_without_await
    func report() async -> DiagnosticsChapter {
        DiagnosticsChapter(title: "Session Logs (OSLog)", diagnostics: Self.makeLogText())
    }
}

extension OSLogReporter {
    /// `OSLogEntryLog` itself has no public initializer, so the filter/format/cap logic below
    /// runs on this plain struct instead - that is what makes it unit-testable.
    struct Entry: Equatable {
        let date: Date
        let level: OSLogEntryLog.Level
        let category: String
        let message: String
    }

    static let maxEntryCount = 2000
    static let maxByteCount = 512 * 1024

    static let header = "Only the main app process is included; Share Extension, Widget and App Clip log into their own processes.\n\n"

    static func makeLogText() -> String {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(timeIntervalSinceLatestBoot: 0)
            let subsystem = Bundle.main.bundleIdentifier

            let entries = try store.getEntries(with: [], at: position, matching: nil)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == subsystem }
                .map { Entry(date: $0.date, level: $0.level, category: $0.category, message: $0.composedMessage) }

            return makeLogText(from: entries)
        } catch {
            return header + "Could not read the session log: \(LogRedact.describe(error))"
        }
    }

    /// Discards `.debug` and `.undefined`, formats and caps the rest. Split out from
    /// `makeLogText()` so tests can exercise it without a real `OSLogStore`.
    static func makeLogText(from entries: [Entry]) -> String {
        let kept = entries.filter { $0.level != .debug && $0.level != .undefined }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        let lines = kept.suffix(maxEntryCount).map { entry in
            "\(formatter.string(from: entry.date))  \(levelName(entry.level))  \(entry.category)  \(entry.message)"
        }

        return header + lastLines(lines, maxByteCount: maxByteCount).joined(separator: "\n")
    }

    /// The tail of `lines` whose combined UTF-8 size stays within `maxByteCount`, in original order.
    static func lastLines(_ lines: [String], maxByteCount: Int) -> [String] {
        var kept: [String] = []
        var byteCount = 0
        for line in lines.reversed() {
            let lineBytes = line.utf8.count + 1
            guard byteCount + lineBytes <= maxByteCount else { break }
            kept.append(line)
            byteCount += lineBytes
        }
        return kept.reversed()
    }

    static func levelName(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .undefined: return "UNDEFINED"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .error: return "ERROR"
        case .fault: return "FAULT"
        @unknown default: return "UNKNOWN"
        }
    }
}
