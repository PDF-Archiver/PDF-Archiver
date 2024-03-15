//
//  SentryBreadcrumbLogger.swift
//  
//
//  Created by Julian Kahnert on 19.01.21.
//

import Logging
import Sentry

public struct SentryBreadcrumbLogger: LogHandler {
    public var metadata: Logger.Metadata
    public var logLevel: Logger.Level = .info

    public init(metadata: Logger.Metadata, logLevel: Logger.Level = .info) {
        self.metadata = metadata
        self.logLevel = logLevel
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        guard level >= logLevel else { return }

        let sentryLevel: SentryLevel
        switch level {
            case .debug, .trace, .notice:
                sentryLevel = .debug
            case .info:
                sentryLevel = .info
            case .warning:
                sentryLevel = .warning
            case .error:
                sentryLevel = .error
            case .critical:
                sentryLevel = .fatal
        }

        let crumb = Breadcrumb()
        crumb.level = sentryLevel
        crumb.category = "\(file) \(function):\(line)"
        crumb.message = message.description
        crumb.data = metadata?.reduce(into: [String: Any]()) { (result, metadata) in
            result[metadata.key] = metadata.value
        }
        crumb.timestamp = Date()
        SentrySDK.addBreadcrumb(crumb)
    }
}
