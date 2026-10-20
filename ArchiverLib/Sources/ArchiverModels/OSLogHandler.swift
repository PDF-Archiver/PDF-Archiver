import Foundation
import Logging
import os

/// Forwards swift-log to the unified logging system under the app's subsystem, which is what
/// `OSLogReporter` filters the diagnostics report on.
public struct OSLogHandler: LogHandler {
    // OSLog decides per type what it keeps, so this handler lets every level through.
    public var logLevel: Logging.Logger.Level = .trace
    public var metadata = Logging.Logger.Metadata()

    private let osLog: os.Logger

    public init(label: String) {
        osLog = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "de.JulianKahnert.PDFArchiveViewer", category: label)
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(event: LogEvent) {
        var merged = metadata
        if let explicit = event.metadata {
            merged.merge(explicit) { _, explicit in explicit }
        }
        if let error = event.error {
            merged["error"] = "\(LogRedact.describe(error))"
        }
        let text = Self.composedMessage(event.message.description,
                                        metadata: merged,
                                        file: event.file,
                                        function: event.function,
                                        line: event.line)
        // One public string: the values are redacted at the call site, and the diagnostics report
        // has to be able to read them.
        osLog.log(level: event.level.osLogType, "\(text, privacy: .public)")
    }

    /// The line format from before the swift-log migration, which the diagnostics report and
    /// `SensitivePathFilter` were written against.
    static func composedMessage(_ message: String,
                                metadata: Logging.Logger.Metadata,
                                file: String,
                                function: String,
                                line: UInt) -> String {
        var metadataText = ""
        if !metadata.isEmpty {
            // `Dictionary` has no stable order - sorted here, or the same call site would print its
            // fields in a different order on every launch.
            let fields = metadata.sorted { $0.key < $1.key }.reduce("") { partialResult, element in
                "\(partialResult), [\(element.key): \(element.value)]"
            }
            metadataText = " metadata: \(fields),"
        }
        let fileName = file.split(separator: "/").last.map(String.init) ?? file
        return "\(message) -\(metadataText) file: \(fileName) \(function):\(line)"
    }
}

private extension Logging.Logger.Level {
    var osLogType: OSLogType {
        switch self {
        case .trace, .debug:
            return .debug

        case .info:
            return .info

        case .notice:
            return .default

        // Like `os.Logger.warning`: `.info` would keep a warning out of the persisted log.
        case .warning, .error:
            return .error

        case .critical:
            return .fault
        }
    }
}
