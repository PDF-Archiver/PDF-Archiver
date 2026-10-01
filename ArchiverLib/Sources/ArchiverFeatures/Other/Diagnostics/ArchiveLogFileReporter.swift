import ArchiverModels
import Diagnostics
import Foundation

/// Adds this device's ``ArchiveLogFile`` files as a diagnostics chapter - unlike OSLog they
/// cover earlier launches and background runs too.
struct ArchiveLogFileReporter: DiagnosticsReporting {
    static let noLogsText = "No diagnostic logs on this device."

    // `report()` is `async` to satisfy `DiagnosticsReporting`; reading the files is synchronous.
    // swiftlint:disable:next async_without_await
    func report() async -> DiagnosticsChapter {
        // Taken from the running log rather than resolved here: resolving it starts `ArchiveStore`.
        guard let directory = ArchiveLogFile.shared.directory else {
            return DiagnosticsChapter(title: "Diagnostic Logs", diagnostics: "Only TestFlight and debug builds write diagnostic logs.")
        }
        return DiagnosticsChapter(title: "Diagnostic Logs",
                                  diagnostics: Self.makeLogText(in: directory, maxByteCount: 1024 * 1024))
    }

    /// The newest lines of all `.jsonl` files, oldest file first, within `maxByteCount`.
    static func makeLogText(in directory: URL, maxByteCount: Int) -> String {
        let fileURLs: [URL]
        do {
            fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "jsonl" }
                // The names start with the launch time, so the name order is the time order.
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch CocoaError.fileReadNoSuchFile {
            return noLogsText
        } catch {
            return "Could not list the diagnostic logs: \(LogRedact.describe(error))"
        }
        guard !fileURLs.isEmpty else { return noLogsText }

        var sections: [String] = []
        var remainingByteCount = maxByteCount
        for url in fileURLs.reversed() {
            let heading = "== \(url.lastPathComponent) =="
            remainingByteCount -= heading.utf8.count + 1
            guard remainingByteCount > 0 else { break }

            let lines: [String]
            do {
                lines = try String(contentsOf: url, encoding: .utf8)
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .map(String.init)
            } catch {
                sections.append("\(heading)\nCould not read this file: \(LogRedact.describe(error))")
                continue
            }
            let kept = OSLogReporter.lastLines(lines, maxByteCount: remainingByteCount)
            sections.append(([heading] + kept).joined(separator: "\n"))
            remainingByteCount -= kept.reduce(0) { $0 + $1.utf8.count + 1 }
            guard kept.count == lines.count else { break }
        }
        return sections.reversed().joined(separator: "\n\n")
    }
}
