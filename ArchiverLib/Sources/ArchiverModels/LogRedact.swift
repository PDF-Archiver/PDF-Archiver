import CryptoKit
import Foundation

/// Errors that may be logged verbatim because their description carries no file name,
/// path or document content.
public protocol LogSafeError: Error {
    var logDescription: String { get }
}

public enum LogRedact {
    /// Stable, non-reversible token for a document. Two log lines about the same file share a
    /// token, so a support report stays traceable without exposing description or tags.
    public static func token(_ url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.lastPathComponent.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined().prefix(8)
        let ext = url.pathExtension.isEmpty ? "-" : url.pathExtension
        return "doc:\(hex).\(ext)"
    }

    /// Shape of a URL without its content - enough to tell a nesting or file-type problem apart.
    public static func shape(_ url: URL) -> String {
        let ext = url.pathExtension.isEmpty ? "-" : url.pathExtension
        return "depth:\(url.pathComponents.count) ext:\(ext)"
    }

    /// Foundation puts NSFilePath and NSURL into userInfo and the file name into
    /// localizedDescription - both are dropped here.
    public static func describe(_ error: Error) -> String {
        if let safe = error as? LogSafeError {
            return safe.logDescription
        }
        let nsError = error as NSError
        return "\(nsError.domain)#\(nsError.code)"
    }
}
