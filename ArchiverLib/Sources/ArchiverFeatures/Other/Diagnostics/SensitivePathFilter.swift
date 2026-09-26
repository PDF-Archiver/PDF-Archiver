import ArchiverModels
import Diagnostics
import Foundation

/// Second net over the whole report, in case a value slipped past the redaction at the log call
/// site (Schritt 2). Only `String` and `[String: String]` chapters are filtered - the two
/// `Diagnostics` payload types the reporters in this app actually produce.
enum SensitivePathFilter: DiagnosticsReportFilter {
    static func filter(_ diagnostics: Diagnostics) -> Diagnostics {
        switch diagnostics {
        case let text as String:
            return LogRedact.redacted(text)

        case let pairs as [String: String]:
            return pairs.mapValues(LogRedact.redacted)

        default:
            return diagnostics
        }
    }
}
