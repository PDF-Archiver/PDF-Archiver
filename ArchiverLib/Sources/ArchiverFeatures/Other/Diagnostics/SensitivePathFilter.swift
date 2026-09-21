import Diagnostics
import Foundation

/// Second net over the whole report, in case a value slipped past the redaction at the log call
/// site (Schritt 2). Only `String` and `[String: String]` chapters are filtered - the two
/// `Diagnostics` payload types the reporters in this app actually produce.
enum SensitivePathFilter: DiagnosticsReportFilter {
    static func filter(_ diagnostics: Diagnostics) -> Diagnostics {
        switch diagnostics {
        case let text as String:
            return redacted(text)

        case let pairs as [String: String]:
            return pairs.mapValues(redacted)

        default:
            return diagnostics
        }
    }

    private static func redacted(_ text: String) -> String {
        var result = text.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        result = result.replacingOccurrences(of: NSUserName(), with: "<user>")
        result = result.replacingOccurrences(of: #"[^\s"'<>]+\.pdf"#, with: "<document>", options: .regularExpression)
        return result
    }
}
